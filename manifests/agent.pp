
class teamcity::agent(
  $agentname,
  $bucket,
  $username = $teamcity::params::username,
  $server_url = $teamcity::params::server_url,
  $archive_name = $teamcity::params::archive_name,
  $agent_dir = $teamcity::params::agent_dir,
  $destination_dir = $teamcity::params::destination_dir,
  $priority =  $teamcity::params::priority,
  $teamcity_agent_mem_opts = $teamcity::params::teamcity_agent_mem_opts,
  $work_dir = $teamcity::params::work_dir,
  ) inherits teamcity::params {

  class { 'java':
    distribution => 'jdk',
    version      => 'latest',
  }

  user { "$username":
    ensure     => "present",
    managehome => true,
  }

  s3file { "/root/$archive_name":
    ensure     => 'present',
    bucket     => "$bucket",
    object_key => "$archive_name",
  }

  file { "$destination_dir":
    ensure => "directory",
    require => [ S3file["/root/$archive_name"] ],
  }

  exec { "extract-build-agent":
    command => "unzip -d $destination_dir/$agent_dir /root/$archive_name && cp $destination_dir/$agent_dir/conf/buildAgent.dist.properties $destination_dir/$agent_dir/conf/buildAgent.properties && chown $username:$username $destination_dir/$agent_dir -R",
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin:/opt/local/bin",
    creates => "$destination_dir/$agent_dir",
    require => [ File["$destination_dir"], User["$username"], Package["unzip"], ],
    logoutput => "on_failure",
  }

  # make 'bin' folder executable
  file { "$destination_dir/$agent_dir/bin/":
    mode => 755,
    recurse => true,
    require => Exec["extract-build-agent"],
  }

  file { "properties.aug":
    path    => "/usr/share/augeas/lenses/dist/properties.aug",
    content => template("${module_name}/properties.aug.erb"),
  }

  augeas { "buildAgent.properties":
    lens    => "properties.aug",
    incl    => "$destination_dir/$agent_dir/conf/buildAgent.properties",
    changes => [
        "set name $agentname",
        "set serverUrl $server_url",
        "set workDir $work_dir",
    ],
    require => [ File["properties.aug"], Exec["extract-build-agent"], ],
  }

  file { "buildAgent.properties":
    path    => "$destination_dir/$agent_dir/conf/buildAgent.properties",
    owner   => $username,
  }

  # init.d script
  file { "/etc/init.d/build-agent":
    owner   => "root",
    group   => "root",
    mode    => 755,
    content => template("teamcity/build-agent.erb"),
    require => File["$destination_dir/$agent_dir/bin/"],
  }

  file { "/etc/profile.d/${priority}-teamcity.sh":
    owner   => "root",
    group   => "root",
    mode    => 755,
    content => template("${module_name}/teamcity-profile.erb"),
  }

  # todo: not sure about this stuff. Check with devops dave.
  # init.d autostart
  exec { "update-rc.d build-agent defaults":
    cwd => "/etc/init.d/",
    creates => ["/etc/rc0.d/K20build-agent",
                "/etc/rc1.d/K20build-agent",
                "/etc/rc2.d/S20build-agent",
                "/etc/rc3.d/S20build-agent",
                "/etc/rc4.d/S20build-agent",
                "/etc/rc5.d/S20build-agent",
                "/etc/rc6.d/K20build-agent"
                ],
    require => [ File["/etc/init.d/build-agent"], File["/etc/profile.d/${priority}-teamcity.sh"], File["buildAgent.properties"] ],
  }

  service { "build-agent":
    ensure => running,
    enable => true,
    hasstatus => false,
    require => [Exec ["update-rc.d build-agent defaults"], Class['java'],],
  }
}
