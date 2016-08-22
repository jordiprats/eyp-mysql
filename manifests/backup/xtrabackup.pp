define mysql::backup::xtrabackup (
                                    $destination,
                                    $retention    = undef,
                                    $logdir       = undef,
                                    $compress     = true,
                                    $mailto       = undef,
                                    $idhost       = undef,
                                    $backupscript = '/usr/local/bin/xtrabackup',
                                    $hour         = '2',
                                    $minute       = '0',
                                    $month        = undef,
                                    $monthday     = undef,
                                    $weekday      = undef,
                                    $setcron      = true,
                                    $backupid     = 'MySQL',
                                  ) {
  #
  validate_absolute_path($destination)

  if defined(Class['netbackupclient'])
  {
    netbackupclient::includedir { $destination: }
  }

  exec { "xtrabackup mkdir_p_${destination}":
    command => "/bin/mkdir -p ${destination}",
    creates => $destination,
  }

  file { $destination:
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => Exec["xtrabackup mkdir_p_${destination}"]
  }

  # backup script

  file { $backupscript:
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    content => template("${module_name}/backup/xtrabackup/backupxtrabackup.erb")
  }

  file { "${backupscript}.config":
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => template("${module_name}/backup/xtrabackup/backupxtrabackupconfig.erb")
  }


  if($setcron)
  {
    cron { "cronjob mysqldump ${name}":
      command  => $backupscript,
      user     => 'root',
      hour     => $hour,
      minute   => $minute,
      month    => $month,
      monthday => $monthday,
      weekday  => $weekday,
      require  => File[ [ $backupscript, $destination, "${backupscript}.config" ] ],
    }
  }

  #
  # https://www.percona.com/doc/percona-xtrabackup/2.3/installation.html#installing-percona-xtrabackup-from-repositories
  #

}