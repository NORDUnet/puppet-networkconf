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
      exec { 'restart_docker':
        command     => '/bin/systemctl restart docker',
        onlyif      => '/bin/systemctl -q is-active docker',
        refreshonly => true
      }
      exec { 'restart':
        command     => 'ifdown -a && ip address flush up && ifup -a',
        path        => '/sbin',
        refreshonly => true,
      }

      file { '/etc/network/interfaces':
        content => template('networkconf/debian/interfaces'),
        notify  => [ Exec['restart'], Exec['restart_docker'] ]
      }

      file { '/etc/network/interfaces.d':
        ensure  => 'directory',
        purge   => true,
        recurse => true,
        notify  => [ Exec['restart'], Exec['restart_docker'] ]
      }

      $network_hash.each |$k, $v| {
        $ifname = $k
        if has_key($v, 'ip') {
          if $v['ip'] =~ Array {
            $ipv4addr = ip_address($v['ip'][0])
            $ipv4netmask = ip_netmask($v['ip'][0])
            $ipv4aliases = delete_at(zip($v['ip'].map |$cidr| { ip_address($cidr) }, $v['ip'].map |$cidr| { ip_netmask($cidr) }), 0)
          } else {
            $ipv4addr = ip_address($v['ip'])
            $ipv4netmask = ip_netmask($v['ip'])
          }
          $ipv4gateway = $v['gateway']
        }
        if has_key($v, 'ipv6') {
          if $v['ipv6'] =~ Array {
            $ipv6addr = ip_address($v['ipv6'][0])
            $ipv6prefixlength = ip_prefixlength($v['ipv6'][0])
            $ipv6aliases = delete_at(zip($v['ipv6'].map |$cidr| { ip_address($cidr) }, $v['ipv6'].map |$cidr| { ip_prefixlength($cidr) }), 0)
          } else {
            $ipv6addr = ip_address($v['ipv6'])
            $ipv6prefixlength = ip_prefixlength($v['ipv6'])
          }
          $ipv6gateway = $v['gatewayv6']
        }
        if has_key($v, 'routes') {
          $routes = $v['routes']
        }
        file { "/etc/network/interfaces.d/${ifname}.cfg":
          content => template('networkconf/debian/ensXXX.cfg.erb'),
          notify  => [ Exec['restart'], Exec['restart_docker'] ]
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

      $network_hash.each |$k, $v| {
        $ifname = $k
        if has_key($v, 'ip') {
          if $v['ip'] =~ Array {
            $ipv4addr = ip_address($v['ip'][0])
            $ipv4netmask = ip_netmask($v['ip'][0])
          } else {
            $ipv4addr = ip_address($v['ip'])
            $ipv4netmask = ip_netmask($v['ip'])
          }
          $ipv4gateway = $v['gateway']
        }
        if has_key($v, 'ipv6') {
          if $v['ipv6'] =~ Array {
            $ipv6addr = ip_address($v['ipv6'][0])
            $ipv6prefixlength = ip_prefixlength($v['ipv6'][0])
          } else {
            $ipv6addr = ip_address($v['ipv6'])
            $ipv6prefixlength = ip_prefixlength($v['ipv6'])
          }
          $ipv6gateway = $v['gatewayv6']
        }
        file { "/etc/sysconfig/network-scripts/ifcfg-${ifname}":
          content => template('networkconf/redhat/ifcfg-XXX.erb'),
          notify  => Exec['restart']
        }
      }

      file { '/etc/resolv.conf':
        content => inline_template('# This file is managed by puppet
<% @nameservers.each do |ns| -%>
<%= "nameserver #{ns}" %>
<% end -%>
<%= "search #{@searchpath.join(" ")}" %>')
      }
    }
    default: {
      err('Unsupported OS family')
    }
  }
}
