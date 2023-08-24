<?php

/**
 * Fired during plugin activation
 *
 * @link       https://www.microsoft.com
 * @since      1.0.0
 *
 * @package    App_service_email
 * @subpackage App_service_email/includes
 */

/**
 * Fired during plugin activation.
 *
 * This class defines all code necessary to run during the plugin's activation.
 *
 * @since      1.0.0
 * @package    App_service_email
 * @subpackage App_service_email/includes
 * @author     Microsoft <wordpressdev@microsoft.com>
 */
class App_service_email_Activator {

	/**
	 * Short Description. (use period)
	 *
	 * Long Description.
	 *
	 * @since    1.0.0
	 */
	public static function activate() {
		require_once plugin_dir_path( __FILE__ ) . '../admin/logger/class-azure_app_service_email-logger.php';
        $logger =  new Azure_app_service_email_logger();
		$logger->email_logger_create_table();	

	}

}
