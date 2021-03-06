# Configure the Glance service
#
# [*backend*]
#   (optional) Glance backend to use.
#   Can be 'file' or 'rbd'.
#   Defaults to 'file'.
#
class openstack_integration::glance (
  $backend = 'file',
) {

  rabbitmq_user { 'glance':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'glance@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  class { '::glance::db::mysql':
    password => 'glance',
  }
  include ::glance
  include ::glance::client
  class { '::glance::keystone::auth':
    password => 'a_big_secret',
  }
  case $backend {
    'file': {
      include ::glance::backend::file
      $backend_store = ['file']
    }
    'rbd': {
      class { '::glance::backend::rbd':
        rbd_store_user => 'openstack',
        rbd_store_pool => 'glance',
      }
      $backend_store = ['rbd']
      # make sure ceph pool exists before running Glance API
      Exec['create-glance'] -> Service['glance-api']
    }
    default: {
      fail("Unsupported backend (${backend})")
    }
  }
  $http_store = ['http']
  $glance_stores = concat($http_store, $backend_store)
  class { '::glance::api':
    debug               => true,
    verbose             => true,
    database_connection => 'mysql+pymysql://glance:glance@127.0.0.1/glance?charset=utf8',
    keystone_password   => 'a_big_secret',
    workers             => 2,
    known_stores        => $glance_stores,
  }
  class { '::glance::registry':
    debug               => true,
    verbose             => true,
    database_connection => 'mysql+pymysql://glance:glance@127.0.0.1/glance?charset=utf8',
    keystone_password   => 'a_big_secret',
    workers             => 2,
  }
  class { '::glance::notify::rabbitmq':
    rabbit_userid       => 'glance',
    rabbit_password     => 'an_even_bigger_secret',
    rabbit_host         => '127.0.0.1',
    notification_driver => 'messagingv2',
  }

}
