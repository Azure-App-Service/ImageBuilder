# WDEV Logger #

WPMUDEV Logger - A simple logger module.

It's created based on Hummingbird\Core\Logger.
This logger lib will handle the old messages based on the expected size.
This means, it will try to get rid of the old messages if the file size is larger than the max size of the log file.

# How to use it #

1. Insert this repository as **sub-module** into the existing project

2. Include the file `wdev-logger.php` in your main plugin file.

3. Register a logger instance via method: WDEV_Logger::create


## Code Example ##

```
#!php

<?php
// Load the WDEV Logger module.
include_once 'lib/wdev-logger/wdev-logger.php';

$logger = WDEV_Logger::create(array(
    'max_log_size'                 => 10,//10MB
    'expected_log_size_in_percent' => 0.7,//70%
    'log_dir'                      => 'uploads/your_plugin_name',
    'add_subsite_dir'              => true,//For MU site, @see self::get_log_directory()
    'modules'                      => array(
        'foo' => array(
            'is_private' => true,//-log.php,
            'log_dir'    => 'uploads/specific/log_dir',
        ),
        //uploads/your_plugin_name/bazz-debug.log
        'baz' => array(
            'name'              => 'bazz',
            'max_log_size'      => 5,//5MB,
        ),
        //It's not required to register a main module, by default it will be index ($logger->index()->...)
        'main_module' => array(
            'is_global_module' => true,
            'log_level'        => LOG_DEBUG,// @see self::$log_level
        )
     )
), $your_plugin_key_or_null);
// We will use this name ($your_plugin_key_or_null) to save the settings, we can leave it empty to use the folder plugin name.
// @see WDEV_Logger::get_option_key() for more detail.

$logger->foo()->error('Log an error.');// result: [...DATE...] Error: Log an error. File path: [uploads/specific/log_dir/foo-log.php]
$logger->foo()->warning('Log a warning');
$logger->foo()->notice('Log a notice');
$logger->foo()->info('Log info');
//Main Module.
$logger->main_module()->error('Log an error for main module');
//Or
$logger->error('Log an error');

//Delete log file.
$logger->foo()->delete();//Delete the log file of module Foo.
$logger->delete();//Delete log file for the main module.

/**
 * By default, Logger only log when the user enable WP_DEBUG_LOG, but we can overwrite it via setting
 * or via methods.
 * 
 * 1. Log mode:
 * define('WP_DEBUG_LOG', LOG_DEBUG );
 *
 * LOG_ERR or 3     => Only log Error type.
 * LOG_WARNING or 4 => Only log Warning type.
 * LOG_NOTICE or 5  => Only log Notice type.
 * LOG_INFO or 6    => Only log Info type.
 * LOG_DEBUG or 7   => Log Error, Warning and Notice type.
 * self::WPMUDEV_DEBUG_LEVEL or 10 or TRUE => for all message types.
 */
// or set log mode via set_log_level();
$logger->set_log_level( LOG_DEBUG );// It will set for global module, and other modules can inherit from global module.
// We can do like this to only activate it for the main module.
$logger->main_module()->set_log_level( true );// While setting the log level via method, we will convert true to WPMUDEV_DEBUG_LEVEL.

/**
 * 2. Debug mode.
 * define('WP_DEBUG', LOG_DEBUG );
 * 
 * We use this config to enable option to log the backtrace:
 * LOG_ERR or 3     => Only for Error type.
 * LOG_WARNING or 4 => Only for Warning type.
 * LOG_NOTICE or 5  => Only for Notice type.
 * LOG_INFO or 6    => Only for Info type.
 * LOG_DEBUG or 7   => For Error, Warning and Notice type.
 * self::WPMUDEV_DEBUG_LEVEL or 10 => for all message types.
 * 
 * Or via method.
 */
$logger->set_debug_level( LOG_DEBUG );

/**
 * Get the download link
 */

$download_link_foo_log = $logger->foo()->get_download_link();

/**
 * Delete the log file via ajax.
 */

add_action( 'admin_footer', 'wpmudev_logger_ajax' ); // Write our JS below here

function wpmudev_logger_ajax() {
    ?>
    <script type="text/javascript" >
    jQuery(document).ready(function($) {

        var data = {
            'action': 'wdev_logger_action',
            'log_action': 'delete',
            'log_module': 'foo',
            <?php echo WDEV_Logger::NONCE_NAME;?>: '<?php echo wp_create_nonce('action_[your_option_key]');?>'
        };
        jQuery.post(ajaxurl, data, function(response) {
            console.log(response);
        });
    });
    </script> <?php
    }
}

/**
 * Cleanup.
 */
WDEV_Logger::create_from_option( $your_plugin_key_or_null )->cleanup();

// End.
```