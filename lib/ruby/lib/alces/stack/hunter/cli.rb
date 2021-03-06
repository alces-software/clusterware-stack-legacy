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
require 'alces/stack'
require 'alces/tools/cli'

module Alces
  module Stack
    module Hunter
      class CLI
        include Alces::Tools::CLI

        root_only
        name 'alces-node-hunter'
        description "Automatically detect booting nodes and update infrastructure database with detected information"
        log_to File.join(Alces::Stack.config.log_root,'alces-node-hunter.log')

        option :interface,
               'Specify local interface on which to sniff',
               '--interface', '-i',
               default: "eth0",
               required: true

        option :hostname,
               'Specify default root of identifier for detected machines',
               '--identifier', '-n',
               default: "node",
               required: true

        option :sequence_length,
               'Specify numeric sequence length for detected machines',
               '--length', '-l',
               default: 2,
               required: true

        option :sequence_start,
               'Specify start integer for detected machines',
               '--start', '-s',
               default: 0,
               required: true

        option :cobbler_interface,
               'Specify cobbler interface',
               '--cobblerinterface',
               default: 'eth0',
               required: true

        def setup_signal_handler
          trap('INT') do
            STDERR.puts "Exiting..." unless @exiting
            @exiting = true
            Kernel.exit(0)
          end
        end

        def execute
          setup_signal_handler

          Alces::Stack::Hunter.
            listen!( interface,
                     name: hostname,
                     name_sequence_start: sequence_start,
                     name_sequence_length: sequence_length,
                     cobbler_interface: cobbler_interface,
                     )
        end
      end
    end
  end
end
