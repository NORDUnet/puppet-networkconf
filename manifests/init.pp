# Class: networkconf
# ===========================
#
# Puppet module for configuring IPv4 and IPv6 on Ubuntu and CentOS
#
# Parameters
# ----------
#
# $network_hash
#
#
# Examples
# --------
#
# Authors
# -------
#
# Jesper B. Rosenkilde <jbr@nordu.net>
#
# Copyright
# ---------
# Copyright (c) 2017, NORDUnet A/S
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.  Redistributions in binary
# form must reproduce the above copyright notice, this list of conditions and the
# following disclaimer in the documentation and/or other materials provided with
# the distribution.  Neither the name of the NORDUnet nor the names of its
# contributors may be used to endorse or promote products derived from this
# software without specific prior written permission.  THIS SOFTWARE IS PROVIDED
# BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

class networkconf
(
  Hash $network_hash = {},
  Array $nameservers = [],
  Array $searchpath = []
)
{

  case $::os['family'] {
    'Debian': {
      file { '/etc/network/interfaces':
        content => template('networkconf/debian/interfaces')
      }
      exec { 'restart':
        command     => 'ifdown -a && ip address flush up && ifup -a',
        path        => '/sbin',
        refreshonly => true
      }

      file { '/etc/network/interfaces.d':
        ensure  => 'directory',
        purge   => true,
        recurse => true,
        notify  => Exec['restart']
      }

      $nameservers = join($nameservers, ' ')
      $searchpath = join($searchpath, ' ')

      $network_hash.each |$k, $v| {
        $ifname = $k
        if has_key($v, 'ip') {
          $ipv4addr = ip_address($v['ip'])
          $ipv4netmask = ip_netmask($v['ip'])
          $ipv4gateway = $v['gateway']
        }
        if has_key($v, 'ipv6') {
          $ipv6addr = ip_address($v['ipv6'])
          $ipv6prefixlength = ip_prefixlength($v['ipv6'])
          $ipv6gateway = $v['gatewayv6']
        }
        file { "/etc/network/interfaces.d/${ifname}.cfg":
          content => template('networkconf/debian/ensXXX.cfg.erb'),
          notify  => Exec['restart']
        }
      }

    }
    'RedHat': {
      exec { 'restart':
        command     => '/usr/bin/systemctl restart network',
        path        => '/sbin',
        refreshonly => true
      }

      file { '/etc/sysconfig/network-scripts/ifcfg-eth0':
        ensure => 'absent'
      }

      $searchpath = join($searchpath, ' ')

      $network_hash.each |$k, $v| {
        $ifname = $k
        if has_key($v, 'ip') {
          $ipv4addr = ip_address($v['ip'])
          $ipv4netmask = ip_netmask($v['ip'])
          $ipv4gateway = $v['gateway']
        }
        if has_key($v, 'ipv6') {
          $ipv6addr = ip_address($v['ipv6'])
          $ipv6prefixlength = ip_prefixlength($v['ipv6'])
          $ipv6gateway = $v['gatewayv6']
        }
        file { "/etc/sysconfig/network-scripts/ifcfg-${ifname}":
          content => template('networkconf/redhat/ifcfg-XXX.erb'),
          notify  => Exec['restart']
        }
      }
    }
    default: {
      err('Unsupported OS family')
    }
  }
}
