<?php
/**
 * Abstract module class: Abstract_Module
 *
 * @since 3.0
 * @package Smush\Core\Modules
 */

namespace Smush\Core\Modules;

use Smush\Core\Settings;
use WP_Smush;

if ( ! defined( 'WPINC' ) ) {
	die;
}

/**
 * Class Abstract_Module
 *
 * @since 3.0
 */
abstract class Abstract_Module {

	/**
	 * Module slug.
	 *
	 * @var string
	 */
	protected $slug;

	/**
	 * Whether module is pro or not.
	 *
	 * @var string
	 */
	protected $is_pro = false;

	/**
	 * Settings instance.
	 *
	 * @since 3.0
	 * @var Settings
	 */
	protected $settings;

	/**
	 * Abstract_Module constructor.
	 *
	 * @since 3.0
	 */
	public function __construct() {
		$this->settings = Settings::get_instance();

		$this->init();
	}

	/**
	 * Initialize the module.
	 *
	 * Do not use __construct in modules, instead use init().
	 *
	 * @since 3.0
	 */
	protected function init() {}

	/**
	 * Return true if the module is activated.
	 *
	 * @return boolean
	 */
	public function is_active() {
		if ( $this->slug ) {
			if ( ! $this->is_pro ) {
				return (bool) $this->settings->get( $this->slug );
			} else {
				return WP_Smush::is_pro() && $this->settings->get( $this->slug );
			}
		}
		return true;
	}

	/**
	 * Return module slug.
	 *
	 * @return string.
	 */
	public function get_slug() {
		return $this->slug;
	}

}
