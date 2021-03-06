################################################################################
# (c) Copyright 2007-2012 Alces Software Ltd & Stephen F Norledge.             #
#                                                                              #
# Alces HPC Software Toolkit                                                   #
#                                                                              #
# This file/package is part of Symphony                                        #
#                                                                              #
# Symphony is free software: you can redistribute it and/or modify it under    #
# the terms of the GNU Affero General Public License as published by the Free  #
# Software Foundation, either version 3 of the License, or (at your option)    #
# any later version.                                                           #
#                                                                              #
# Symphony is distributed in the hope that it will be useful, but WITHOUT      #
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or        #
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License #
# for more details.                                                            #
#                                                                              #
# You should have received a copy of the GNU Affero General Public License     #
# along with Symphony.  If not, see <http://www.gnu.org/licenses/>.            #
#                                                                              #
# For more information on the Symphony Toolkit, please visit:                  #
# https://github.com/alces-software/symphony                                       #
#                                                                              #
################################################################################
require 'alces/tools/logging'
require 'alces/tools/execution'
require 'net/dhcp'
require 'pcaplet'

module Alces
  module Stack
    module Hunter
      class Listener
        include Alces::Tools::Logging
        include Alces::Tools::Execution

        def initialize(interface_name,options={})
          @interface_name=interface_name
          @detection_count=options[:name_sequence_start].to_i || 0
          @default_name_index_size=options[:name_sequence_length].to_i || 2
          @default_name=options[:name] || "node"
          @detected_macs=[]
          @cobbler_interface=options[:cobbler_interface]
        end

        def listen!
          STDERR.puts "WAITING FOR NEW NODES TO APPEAR ON THE NETWORK, PLEASE NETWORK BOOT THEM NOW... (CTRL+C TO TERMINATE)"
          Thread.new do
            network.each do |p|
              process_packet(p.udp_data) if p.udp?
            end
          end
          sleep
        end

        private

        def network
          @network ||= begin
            Pcaplet.new("-s 600 -n -i #{@interface_name}").tap do |network|
              filter = Pcap::Filter.new('udp port 67 and udp port 68', network.capture)
              network.add_filter(filter)
            end
          end
        end

        def process_packet(data)
          info "Processing received UDP packet"
          message = DHCP::Message.from_udp_payload(data, :debug => false)
          process_message(message) if message.is_a?(DHCP::Discover)
        end

        def process_message(message)
          info("Processing DHCP::Discover message options"){ message.options }
          message.options.each do |o|
            detected(hwaddr_from(message)) if pxe_client?(o)
          end
        end

        def hwaddr_from(message)
          info "Determining hardware address"
          message.chaddr.slice(0..(message.hlen - 1)).map do |b|
            b.to_s(16).upcase.rjust(2,'0')
          end.join(':').tap do |hwaddr|
            info "Detected hardware address: #{hwaddr}"
          end
        end

        def pxe_client?(o)
          o.is_a?(DHCP::VendorClassIDOption) && o.payload.pack('C*').tap do |vendor|
            info "Detected vendor: #{vendor}"
          end =~ /^PXEClient/
        end

        def detected(hwaddr)
          return if @detected_macs.include?(hwaddr)
          default_name = sequenced_name

          @detected_macs << hwaddr
          @detection_count += 1

          begin
            STDERR.print "Detected a machine on the network (#{hwaddr}). Please enter the hostname [#{default_name}]: "
            STDERR.flush
            input = gets.chomp
            name = input.empty? ? default_name : input
            STDERR.print "Updating stored information for host:#{name} (#{hwaddr}).."
            STDERR.flush

            update(name, hwaddr)
          rescue Exception => e
            warn e
            STDERR.puts "FAIL: #{e.message}"; STDERR.flush
            STDERR.print "Retry? (Y/N): "; STDERR.flush
            input=gets.chomp
            retry if input.to_s.downcase == 'y'
          end
        end

        def update(name, hwaddr)
          update_cobbler!(name, hwaddr)
          STDERR.puts "OK"
        end

        def update_cobbler!(name, hwaddr)
          ip=`gethostip -d #{name}`.chomp
          raise "Unable to resolve IP for host:#{name}" if ip.to_s.empty?
          run(['cobbler','system','edit','--name',name,"--interface=#{@cobbler_interface}",'--mac',hwaddr,]).tap do |r|
            if r.fail?
              raise "Unable to update cobbler database: #{(r.exc && r.exc.message) || r.stderr}"
            end
          end
        end

        def sequenced_name
          "#{@default_name}#{@detection_count.to_s.rjust(@default_name_index_size,'0')}"
        end
      end
    end
  end
end
