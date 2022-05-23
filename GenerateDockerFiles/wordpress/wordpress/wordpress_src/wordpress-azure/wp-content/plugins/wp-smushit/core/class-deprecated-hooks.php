<?php
/**
 * Deprecated hooks.
 * It's created based on WC_Deprecated_Hooks.
 *
 * @since 3.9.6
 * @package Deprecated_Hooks
 */

namespace Smush\Core;

defined( 'ABSPATH' ) || exit;

/**
 * Handles deprecation notices and triggering of legacy action hooks.
 */
class Deprecated_Hooks {

	/**
	 * Array of deprecated actions hooks we need to handle. Format of 'new' => 'old'.
	 *
	 * @var array
	 */
	private $deprecated_action_hooks = array(
		'wp_smush_before_smush_file' => 'smush_s3_integration_fetch_file',
		'wp_smush_after_remove_file' => 'smush_s3_backup_remove',
	);

	/**
	 * Array of deprecated filters hooks we need to handle. Format of 'new' => 'old'.
	 *
	 * @var array
	 */
	private $deprecated_filter_hooks = array(
		'wp_smush_backup_exists' => 'smush_backup_exists',
		'wp_smush_file_exists'	 => 'smush_file_exists',
	);

	/**
	 * Array of versions on each hook has been deprecated.
	 *
	 * @var array
	 */
	private $deprecated_version = array(
		'smush_backup_exists'             => '3.9.6',
		'smush_s3_integration_fetch_file' => '3.9.6',
		'smush_s3_backup_remove'		  => '3.9.6',
		'smush_file_exists'				  => '3.9.6',
	);

	/**
	 * Is action hook.
	 *
	 * @var bool
	 */
	private $is_action;

	/**
	 * Constructor.
	 *
	 * Hook into the new hook so we can handle deprecated hooks once fired.
	 */
	public function __construct() {
		$deprecated_hooks = array_merge( array_keys( $this->deprecated_action_hooks ), array_keys( $this->deprecated_filter_hooks ) );
		if ( $deprecated_hooks ) {
			foreach ( $deprecated_hooks as $new_action ) {
				add_filter( $new_action, array( $this, 'maybe_handle_deprecated_hook' ), -1000, 8 );
			}
		}
	}

	/**
	 * Get old hooks to map to new hook.
	 *
	 * @param  string $new_hook New hook name.
	 * @return array
	 */
	private function get_old_hooks( $new_hook ) {
		$old_hooks = array();
		if ( isset( $this->deprecated_action_hooks[ $new_hook ] ) ) {
			$old_hooks = $this->deprecated_action_hooks[ $new_hook ];
			$this->is_action = true;
		} elseif ( isset( $this->deprecated_filter_hooks[ $new_hook ] ) ) {
			$old_hooks = $this->deprecated_filter_hooks[ $new_hook ];
			// reset hook type.
			$this->is_action = null;
		}
		$old_hooks = is_array( $old_hooks ) ? $old_hooks : array( $old_hooks );

		return $old_hooks;
	}

	/**
	 * If the hook is Deprecated, call the old hooks here.
	 */
	public function maybe_handle_deprecated_hook() {
		$new_hook          = current_filter();
		$new_callback_args = func_get_args();
		$return_value      = $new_callback_args[0];
		$old_hooks         = $this->get_old_hooks( $new_hook );
		if ( $old_hooks ) {
			foreach ( $old_hooks as $old_hook ) {
				if ( has_filter( $old_hook ) ) {
					$this->display_notice( $old_hook, $new_hook );
					$return_value = $this->trigger_hook( $old_hook, $new_callback_args );
				}
			}
		}

		return $return_value;
	}

	/**
	 * Display a deprecated notice for old hooks.
	 *
	 * @param string $old_hook Old hook.
	 * @param string $new_hook New hook.
	 */
	protected function display_notice( $old_hook, $new_hook ) {
		_deprecated_hook( esc_html( $old_hook ), esc_html( $this->get_deprecated_version( $old_hook ) ), esc_html( $new_hook ) );
	}

	/**
	 * Fire off a legacy hook with it's args.
	 *
	 * @param  string $old_hook          Old hook name.
	 * @param  array  $new_callback_args New callback args.
	 * @return mixed
	 */
	protected function trigger_hook( $old_hook, $new_callback_args ) {
		if ( $this->is_action ) {
			do_action_ref_array( $old_hook, $new_callback_args );
		} else {
			return apply_filters_ref_array( $old_hook, $new_callback_args );
		}
	}

	/**
	 * Get deprecated version.
	 *
	 * @param string $old_hook Old hook name.
	 * @return string
	 */
	protected function get_deprecated_version( $old_hook ) {
		return ! empty( $this->deprecated_version[ $old_hook ] ) ? $this->deprecated_version[ $old_hook ] : WP_SMUSH_VERSION;
	}
}