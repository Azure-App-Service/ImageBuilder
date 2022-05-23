<?php
/**
 * WPMU DEV Logger - A simple logger module
 *
 * @version 1.0.0
 * @author WPMU DEV (Thobk)
 * @package WDEV_Logger
 *
 * It's created based on Hummingbird\Core\Logger.
 * This logger lib will handle the old messages based on the expected size.
 * This means, it will try to get rid of the old messages if the file size is larger than the max size of the log file.
 *
 * Uses:
 * $logger = WDEV_Logger::create(array(
 *      'max_log_size'                 => 10,//10MB
 *      'expected_log_size_in_percent' => 0.7,//70%
 *      'log_dir'                      => 'uploads/your_plugin_name',
 *      'modules'                      => array(
 *          'foo' => array(
 *              'is_private' => true,//-log.php,
 *              'log_dir'    => 'uploads/specific/log_dir',
 *           ),
 *           'baz' => array(
 *              'max_log_size' => 5,//5MB
 *           )
 *      )
 * ));
 * $logger->foo()->error('Log an error into foo module');//[...DATE...] Error: Log an error into foo module. (uploads/specific/log_dir/foo-log.php)
 * $logger->foo()->warning('...a warning...'); $logger->foo()->notice('...a notice...'); $logger->foo()->info('..info...');
 * # Global module: $logger->error('Log an error into the main log file');...(uploads/your_plugin_name/index-debug.log).
 */

if ( ! defined( 'WP_CONTENT_DIR' ) ) {
	exit;
}
if ( ! class_exists( 'WDEV_Logger' ) ) {
	/**
	 * WPMU DEV Logger
	 */
	class WDEV_Logger {

		/**
		 * Logger error.
		 *
		 * @access private
		 * @var    WP_Error|bool $error
		 */
		private $error = false;

		/**
		 * Registered modules.
		 *
		 * @access private
		 * @var    array $modules
		 */
		private $modules = array();

		/**
		 * Current module.
		 *
		 * @access private
		 *
		 * @var string
		 */
		private $current_module;

		/**
		 * Un-lock some limit actions.
		 * Use this to allow some actions which shouldn't call directly.
		 *
		 * @access private
		 *
		 * @var string
		 */
		private $un_lock;

		/**
		 * Nonce name.
		 */
		const NONCE_NAME = '_wdevnonce';

		/**
		 * Register a new debug log level.
		 * It will have full control.
		 */
		const WPMUDEV_DEBUG_LEVEL = 10;

		/**
		 * Debug level.
		 *
		 * We use constant WP_DEBUG to define the debug level, e.g:
		 * define('WP_DEBUG', LOG_DEBUG );
		 *
		 * Add backtrace for debug levels:
		 * LOG_ERR or 3     => Only for Error type.
		 * LOG_WARNING or 4 => Only for Warning type.
		 * LOG_NOTICE or 5  => Only for Notice type.
		 * LOG_INFO or 6    => Only for Info type.
		 * LOG_DEBUG or 7   => For Error, Warning and Notice type.
		 * self::WPMUDEV_DEBUG_LEVEL or 10 => for all message types.
		 *
		 * @access private
		 *
		 * @var integer
		 */
		private $debug_level;

		/**
		 * Log level.
		 *
		 * We use constant WP_DEBUG_LOG to define the log level, e.g:
		 * define('WP_DEBUG_LOG', LOG_DEBUG );
		 *
		 * And by default, we will log all message types. But we can limit it by defining WP_DEBUG_LOG_LOG:
		 * LOG_ERR or 3     => Only log Error type.
		 * LOG_WARNING or 4 => Only log Warning type.
		 * LOG_NOTICE or 5  => Only log Notice type.
		 * LOG_INFO or 6    => Only log Info type.
		 * LOG_DEBUG or 7   => Log Error, Warning and Notice type.
		 * self::WPMUDEV_DEBUG_LEVEL or 10 or TRUE => for all message types.
		 *
		 * @access private
		 *
		 * @var integer
		 */
		private $log_level;

		/**
		 * Default Options.
		 *
		 * @type boolean use_native_filesystem_api
		 * If we can't connect to the Filesystem API, enable this to try to use default PHP functions (WP_Filesystem_Direct).
		 *
		 * @type int max_log_size
		 * Maximum file size for each log file in MB.
		 * Note, set it large might make your site run slower while writing a log or clean the log file.
		 *
		 * @type float expected_log_size_in_percent
		 * Set the expected file log size in percent ( base on $max_log_size ).
		 * E.g. If the log file size is larger than 10MB (15MB) => we will need to reduce  (15 - 10 * 70/100 = 8MB).
		 *
		 * @type string log_dir
		 * Log directory, a sub-folder inside WP_CONTENT_DIR
		 * [WP_CONTENT_DIR]/[log_dir]
		 *
		 * @type boolean add_subsite_dir Allow to add sub-site folder in the MU site.
		 *
		 *
		 * Modules:
		 *
		 * By default, we will add a standard module (index), add a empty module to overwrite it. And we can use it to log the general case.
		 * e.g $logger->index()->log('Something for the general case');
		 *
		 * Module option inherit option from the parent.
		 * These are some new option:
		 * @type boolean is_private
		 * Set is_private is TRUE to use save the log to php file instead of normal .log type.
		 *
		 * Set is_global_module is TRUE to use it as a global/general module.
		 * By default, we will auto register a new global module "index".
		 * With global module we can access the method directly, e.g:
		 * $logger->error('Log an error');
		 *
		 * Default settings:
		 * array(
		 *  'use_native_filesystem_api'    => true,
		 *  'max_log_size'                 => 10,
		 *  'expected_log_size_in_percent' => 0.7,
		 *  'log_dir'                      => 'wpmudev',
		 *  'add_subsite_dir'              => true,
		 *  'modules'                      => array(),
		 * );
		 *
		 * @access private
		 *
		 * @var array
		 */
		private $option;

		/**
		 * Option key name.
		 * Default is wdev_logger_[plugin_name]
		 *
		 * @access private
		 * @var string
		 */
		private $option_key;

		/**
		 * Return the plugin instance
		 *
		 * @param array       $option Logger option.
		 * @param string|null $option_key Option key name.
		 * If $option_key is null we will try to use the plugin folder name instead.
		 * @see self::get_option_key()
		 * @return WDEV_Logger
		 */
		public static function create( $option, $option_key = null ) {
			return new self( $option, $option_key );
		}

		/**
		 * Return the plugin instance from the option.
		 *
		 * @param string|null $option_key Option key name.
		 *
		 * @return WDEV_Logger
		 */
		public static function create_from_option( $option_key = null ) {
			return self::create( array(), $option_key );
		}

		/**
		 * Logger constructor.
		 *
		 * @param array  $option Logger option.
		 * @param string $option_key Option key name.
		 */
		public function __construct( $option, $option_key ) {

			$this->parse_option( $option, $option_key );

			// disable for empty option.
			if ( ! empty( $option ) ) {
				add_action( 'wp_ajax_wdev_logger_action', array( $this, 'process_actions' ) );

				// Add cron schedule to clean out outdated logs.
				add_action( 'wdev_logger_clear_logs', array( $this, 'clear_logs' ) );
				add_action( 'admin_init', array( $this, 'check_cron_schedule' ) );
			}
		}

		/**
		 * Set the current module and we can use this to call some actions.
		 * e.g.
		 * $logger->your_module_1()->error('An error.');
		 * $logger->your_module_1()->notice('A notice.');
		 * $logger->your_module_2()->delete();//delete the log file.
		 *
		 * @param string $name Method name.
		 * @param array  $arguments Arguments.
		 */
		public function __call( $name, $arguments ) {
			if ( $this->set_current_module( $name ) ) {
				$this->un_lock = true;
			} elseif ( $this->enabling_debug_log_mode() ) {
				error_log( sprintf( 'Module "%1$s" does not exists, list of registered modules are ["%2$s"]. Continue with global module "%3$s".', $name, join( '", "', array_keys( $this->modules ) ), $this->option['global_module'] ) );//phpcs:ignore
			}
			return $this;
		}

		/**
		 * Check debug log mode.
		 *
		 * @return boolean.
		 */
		public function enabling_debug_log_mode() {
			return defined( 'WP_DEBUG' ) && WP_DEBUG && defined( 'WP_DEBUG_LOG' ) && WP_DEBUG_LOG;
		}

		/**
		 * Main logging function.
		 *
		 * @param mixed       $message  Data to write to log.
		 * @param string|null $type     Log type (Error, Warning, Notice, etc).
		 */
		public function log( $message, $type = null ) {
			$this->maybe_active_global_module();

			if ( ! $this->should_log( $message, $type ) ) {
				return;
			}

			if ( ! is_string( $message ) ) {
				if ( ! is_scalar( $message ) ) {
					$message = PHP_EOL . print_r( $message, true );
				} else {
					$message = print_r( $message, true );
				}
			}

			if ( ! empty( $type ) && is_string( $type ) ) {
				$type    = strtolower( $type );
				$message = ucfirst( $type ) . ': ' . $message;
			}

			$message = '[' . date( 'c' ) . '] ' . $message;//phpcs:ignore

			// maybe log backtrace.
			if ( $this->get_debug_level() && is_int( $this->debug_level ) && $this->level_can_do( $this->debug_level, $type ) ) {
				$backtrace = debug_backtrace( DEBUG_BACKTRACE_IGNORE_ARGS, 20 );//phpcs:ignore
				$backtrace = array_filter(
					$backtrace,
					function( $trace ) {
						return ! isset( $trace['file'] ) || __FILE__ !== $trace['file'] && false !== strpos( $trace['file'], WP_CONTENT_DIR );
					}
				);
				$message .= PHP_EOL .'['. date('c') .'] Stack trace: '. PHP_EOL . print_r( $backtrace, true );//phpcs:ignore
			}

			return $this->write_log_file( $message );
		}

		/**
		 * Log Error message.
		 * Error: [an error message].
		 *
		 * @param mixed $message Data to write to log.
		 */
		public function error( $message ) {
			return $this->log( $message, 'Error' );
		}

		/**
		 * Log a notice.
		 * Warning: [a notice message].
		 *
		 * @param mixed $message Data to write to log.
		 */
		public function notice( $message ) {
			return $this->log( $message, 'Notice' );
		}

		/**
		 * Log a warning.
		 * Warning: [a warning message].
		 *
		 * @param mixed $message Data to write to log.
		 */
		public function warning( $message ) {
			return $this->log( $message, 'Warning' );
		}

		/**
		 * Log a info.
		 * Info: [a info message].
		 *
		 * @param mixed $message Data to write to log.
		 */
		public function info( $message ) {
			return $this->log( $message, 'Info' );
		}

		/**
		 * Retrieve download link for a log module.
		 *
		 * @param string $module Module slug.
		 * @return string A nonce url to download the module log.
		 */
		public function get_download_link( $module = null ) {
			// set current module.
			$this->register_module( $module );

			return wp_nonce_url(
				add_query_arg(
					array(
						'action'     => 'wdev_logger_action',
						'log_action' => 'download',
						'log_module' => $this->current_module,
					),
					admin_url( 'admin-ajax.php' )
				),
				$this->get_log_action_name(),
				self::NONCE_NAME
			);
		}

		/**
		 * Process logger actions.
		 *
		 * Accepts module name (slug) and action. So far only 'download' and 'delete' actions is supported.
		 */
		public function process_actions() {
			// phpcs:ignore
			if ( isset( $_REQUEST['log_action'], $_REQUEST['log_module'], $_REQUEST[ self::NONCE_NAME ] ) && wp_verify_nonce( $_REQUEST[ self::NONCE_NAME ], $this->get_log_action_name() ) ) { // Input var ok.
				$action = sanitize_text_field( wp_unslash( $_REQUEST['log_action'] ) );   // Input var ok.
				$module = sanitize_text_field( wp_unslash( $_REQUEST['log_module'] ) ); // Input var ok.

				// Not called by a registered module.
				if ( ! isset( $this->modules[ $module ] ) ) {
					/* translators: %s Method name */
					wp_send_json_error( sprintf( __( 'Module %s does not exist.', 'wpmudev' ), $module ) );
				}

				// Only allow these actions.
				if ( in_array( $action, array( 'download', 'delete' ), true ) && method_exists( $this, $action ) ) {
					$should_return = isset( $_SERVER['REQUEST_METHOD'] ) && 'POST' === $_SERVER['REQUEST_METHOD'];
					$result        = call_user_func( array( $this, $action ), $module, $should_return );
					if ( $should_return ) {
						wp_send_json_success( $result );
					}
					exit;
				}
				/* translators: %s Method name */
				wp_send_json_error( sprintf( __( 'Method %s does not exist.', 'wpmudev' ), $action ) );
			}
		}

		/**
		 * Delete current log file.
		 *
		 * @param string $module  Module slug.
		 *
		 * @return bool True on success or false on failure.
		 */
		public function delete( $module = null ) {
			if ( $this->connect_fs() ) {
				global $wp_filesystem;
				// Set current module.
				$this->register_module( $module );
				if ( ! $wp_filesystem->exists( $this->get_file() ) ) {
					return true;
				}
				return $wp_filesystem->delete( $this->get_file(), false, 'f' );
			}

			return false;
		}

		/**
		 * Retrieve option by key.
		 *
		 * @param string $name Key name.
		 *
		 * @return mixed Returns option value.
		 */
		public function get_option( $name ) {
			$this->maybe_active_global_module();
			return $this->get_module_option( $name );
		}

		/**
		 * Retrieve current module option by key.
		 *
		 * @access private
		 *
		 * @param string $name Key name.
		 * @param mixed  $value Default value.
		 *
		 * @return mixed Returns option value.
		 */
		private function get_module_option( $name, $value = null ) {
			if ( $this->current_module && isset( $this->modules[ $this->current_module ][ $name ] ) ) {
				$value = $this->modules[ $this->current_module ][ $name ];
			} elseif ( isset( $this->option[ $name ] ) ) {
				$value = $this->option[ $name ];
			}
			return apply_filters( "wdev_logger_get_option_{$name}", $value, $this->current_module, $this->option );
		}

		/**
		 * Clean up the log dir and delete the option.
		 * That's useful to use it while uninstalling plugin.
		 */
		public function cleanup() {
			if ( $this->connect_fs() ) {
				if ( ! empty( $this->modules ) ) {
					foreach ( $this->modules as $module => $module_option ) {
						$this->delete( $module );
					}
				}

				// delete option.
				delete_site_option( $this->option_key );
			}
		}

		/**
		 * Set debug level.
		 *
		 * @param int $debug_level Debug level to set.
		 */
		public function set_debug_level( $debug_level = LOG_DEBUG ) {
			$is_global_settings = ! $this->un_lock;
			$this->maybe_active_global_module();
			return $this->set_level( $debug_level, 'debug_level', $is_global_settings );
		}

		/**
		 * Set log level.
		 *
		 * @param int $log_level Log level to set.
		 */
		public function set_log_level( $log_level = LOG_DEBUG ) {
			$is_global_settings = ! $this->un_lock;
			$this->maybe_active_global_module();
			return $this->set_level( $log_level, 'log_level', $is_global_settings );
		}

		/**
		 * Retrieve log level.
		 *
		 * @access private
		 *
		 * @return int Log level.
		 */
		private function get_log_level() {
			if ( null === $this->log_level ) {
				$this->log_level = $this->get_module_option( 'log_level', WP_DEBUG_LOG );
			}
			return $this->log_level;
		}

		/**
		 * Retrieve debug level.
		 *
		 * @access private
		 *
		 * @return int Debug level.
		 */
		private function get_debug_level() {
			if ( null === $this->debug_level ) {
				$this->debug_level = $this->get_module_option( 'debug_level', WP_DEBUG );
			}
			return $this->debug_level;
		}

		/**
		 * Set level for DEBUG or DEBUG Log.
		 *
		 * @access private
		 *
		 * @param int    $level Level to set.
		 * @param string $level_type log_level | debug_level.
		 * @param bool   $is_global_settings Set log level for all modules or only specific module.
		 * @return int Current level.
		 */
		private function set_level( $level, $level_type, $is_global_settings = false ) {
			$level = (int) $level;
			if ( $level > 2 && $level < 8 ) {
				$level = intval( $level );
			} elseif ( $level < 1 ) {
				$level = 0;
			} else {
				$level = self::WPMUDEV_DEBUG_LEVEL;
			}
			// If setting level for global module, we will set it in the option, so the module can inherit it.
			if ( $is_global_settings && $this->current_module === $this->option['global_module'] ) {
				$this->option[ $level_type ] = $level;
				$this->{$level_type}         = $level;
			} else {
				$this->modules[ $this->current_module ][ $level_type ] = $level;
				$this->{$level_type}                                   = $level;
			}
			// Save option.
			$this->save_option();
			return $level;
		}

		/**
		 * Download logs.
		 *
		 * @access private
		 *
		 * @param string $module  Module slug.
		 * @param bool   $return  Download file or return the content.
		 */
		private function download( $module = null, $return = false ) {
			if ( $this->connect_fs() ) {
				global $wp_filesystem;

				// Set current module.
				$this->register_module( $module );

				$content = $wp_filesystem->get_contents( $this->get_file() );

				if ( $content && $this->get_module_option( 'is_private' ) ) {
					$content = ltrim( $content, '<?php die(); ?>' );
				}

				if ( $return ) {
					return $content;
				}

				header( 'Content-Description: WPMUDEV log download' );
				header( 'Content-Type: text/plain' );
				header( "Content-Disposition: attachment; filename={$this->current_module}.log" );
				header( 'Content-Transfer-Encoding: binary' );
				header( 'Content-Length: ' . strlen( $content ) );
				header( 'Cache-Control: must-revalidate, post-check=0, pre-check=0' );
				header( 'Expires: 0' );
				header( 'Pragma: public' );

				echo $content;//phpcs:ignore
				exit;
			}
		}

		/**
		 * Retrieve the action name for form/request.
		 *
		 * @access private
		 *
		 * @return string Action name.
		 */
		private function get_log_action_name() {
			return 'action_' . str_replace( 'wdev_logger_', '', $this->option_key );
		}

		/**
		 * Retrieve option key.
		 * We use this as an option key name to save the parsed option.
		 *
		 * @access private
		 *
		 * @param  string $option_key option key name.
		 * @return string Option key name.
		 */
		private function get_option_key( $option_key ) {
			if ( ! $this->option_key ) {
				if ( empty( $option_key ) ) {
					list( $option_key ) = explode( '/', ltrim( str_replace( WP_PLUGIN_DIR, '', __FILE__ ), '/' ) );
				}
				$this->option_key = 'wdev_logger_' . $option_key;
			}

			return $this->option_key;
		}

		/**
		 * Parse option.
		 *
		 * @access private
		 *
		 * @param array  $option Logger option.
		 * @param string $option_key Option key name.
		 * @param bool   $force Parse the option without check from the cache.
		 */
		private function parse_option( $option, $option_key, $force = false ) {
			// Default settings.
			$this->option = array(
				'use_native_filesystem_api'    => true,
				'max_log_size'                 => 10,
				'expected_log_size_in_percent' => 0.7,
				'log_dir'                      => 'wpmudev',
				'add_subsite_dir'              => true,
				'modules'                      => array(),
			);
			if ( $force ) {
				$cached_option = false;
			} else {
				// Try to get from the cache.
				$cached_option = get_site_option( self::get_option_key( $option_key ) );
				if ( $cached_option ) {
					// set option.
					if ( ! empty( $cached_option['option'] ) ) {
						$this->option = $cached_option['option'];
					} else {
						$cached_option = array();
					}
					// set modules.
					if ( ! empty( $cached_option['modules'] ) ) {
						$this->modules = $cached_option['modules'];
					} else {
						$cached_option = array();
					}

					// set current module.
					if ( ! empty( $cached_option['global_module'] ) && isset( $this->modules[ $cached_option['global_module'] ] ) ) {
						$this->current_module          = $cached_option['global_module'];
						$this->option['global_module'] = $this->current_module;
					} else {
						$cached_option = array();
					}
				}
			}

			// Parse option, don't parse the option is empty.
			if ( ! empty( $option ) && ( $force || ! $cached_option ) ) {
				$option = wp_parse_args( $option, $this->option );
				if ( empty( $option['modules'] ) ) {
					// Default module.
					$option['modules']['index'] = array(
						'is_global_module' => 1,
					);
				}

				$modules = $option['modules'];
				unset( $option['modules'] );
				// Sanitize option.
				array_walk( $option, array( $this, 'sanitize_option' ) );
				$this->option = $option;

				// Parse modules.
				foreach ( $modules as $module_slug => $module_option ) {
					if ( empty( $module_slug ) ) {
						continue;
					}
					$module_slug = str_replace( '-', '_', sanitize_key( $module_slug ) );
					// If the module_option is empty, we will set it as a general module.
					if ( ! empty( $module_option['is_global_module'] ) ) {
						$this->current_module = $module_slug;
					}

					$module_option = wp_parse_args( $module_option, $this->option );
					array_walk( $module_option, array( $this, 'sanitize_option' ) );
					if ( empty( $module_option['name'] ) ) {
						$module_option['name'] = str_replace( '_', '-', $module_slug );
					}
					$module_option['name']         = sanitize_title( $module_option['name'] );
					$this->modules[ $module_slug ] = $module_option;
				}

				// Maybe activate the general module.
				if ( empty( $this->current_module ) ) {
					$this->modules['index'] = $this->option;
					$this->current_module   = 'index';
				}
				$this->option['global_module'] = $this->current_module;

				// Save option to DB.
				$this->save_option();
			}
		}

		/**
		 * Save option.
		 *
		 * @access private
		 *
		 * @return boolean True on success, false on failure
		 */
		private function save_option() {
			return update_site_option(
				$this->option_key,
				array(
					'option'        => $this->option,
					'modules'       => $this->modules,
					'global_module' => $this->current_module,
				)
			);
		}

		/**
		 * Sanitize option.
		 *
		 * @access private
		 *
		 * @param mixed  $option option value.
		 * @param string $key option key.
		 * @return void
		 */
		private function sanitize_option( &$option, $key ) {
			switch ( $key ) {
				case 'max_log_size':
					$option = abs( (int) $option );
					return;
				case 'expected_log_size_in_percent':
					$option = abs( (float) $option );
					if ( $option > 1 ) {
						$option = 0.9;
					}
					return;
				case 'log_dir':
					if ( empty( $option ) ) {
						$option = 'wpmudev';
					} else {
						$option = preg_replace( '#[^a-z0-9_\/\-]#', '', $option );
					}
					return;
				// We ignore this property to avoid conflict with the cached file name.
				case 'file':
					// Don't allow to set this option directly, please try to use is_global_module instead.
				case 'global_module':
					$option = null;
					return;
			}

			if ( is_bool( $option ) ) {
				return $option;
			} elseif ( empty( $option ) ) {
				if ( isset( $this->option[ $key ] ) ) {
					$option = $this->option[ $key ];
				} else {
					$option = null;
				}
			} elseif ( is_scalar( $option ) ) {
				$option = sanitize_text_field( $option );
			} else {
				$option = null;
			}
		}

		/**
		 * Retrieve filesystem credentials.
		 * By default, if the access method is not "direct" type, function "request_filesystem_credentials" will return a form
		 * if there is any missing from credentials configs. So we use this custom function to avoid this case.
		 *
		 * @see request_filesystem_credentials()
		 * @link https://developer.wordpress.org/reference/functions/request_filesystem_credentials/
		 *
		 * @param string $type Access method type: direct | ftpext | ssh2 | ftpsockets.
		 *
		 * @access private
		 *
		 * @return mixed
		 */
		private function get_filesystem_credentials( $type ) {
			if ( 'direct' === $type ) {
				return true;
			}

			$credentials = get_option(
				'ftp_credentials',
				array(
					'hostname' => '',
					'username' => '',
				)
			);

			$ftp_constants = array(
				'hostname'    => 'FTP_HOST',
				'username'    => 'FTP_USER',
				'password'    => 'FTP_PASS',
				'public_key'  => 'FTP_PUBKEY',
				'private_key' => 'FTP_PRIKEY',
			);

			// If defined, set it to that. Else, if POST'd, set it to that. If not, set it to an empty string.
			// Otherwise, keep it as it previously was (saved details in option).
			foreach ( $ftp_constants as $key => $constant ) {
				if ( defined( $constant ) ) {
					$credentials[ $key ] = constant( $constant );
				} elseif ( ! isset( $credentials[ $key ] ) ) {
					$credentials[ $key ] = '';
				}
			}

			// Sanitize the hostname, some people might pass in odd data.
			$credentials['hostname'] = preg_replace( '|\w+://|', '', $credentials['hostname'] ); // Strip any schemes off.

			if ( strpos( $credentials['hostname'], ':' ) ) {
				list( $credentials['hostname'], $credentials['port'] ) = explode( ':', $credentials['hostname'], 2 );
				if ( ! is_numeric( $credentials['port'] ) ) {
					unset( $credentials['port'] );
				}
			} else {
				unset( $credentials['port'] );
			}

			if ( ( defined( 'FTP_SSH' ) && FTP_SSH ) || ( defined( 'FS_METHOD' ) && 'ssh2' === FS_METHOD ) ) {
				$credentials['connection_type'] = 'ssh';
			} elseif ( ( defined( 'FTP_SSL' ) && FTP_SSL ) && 'ftpext' === $type ) { // Only the FTP Extension understands SSL.
				$credentials['connection_type'] = 'ftps';
			} elseif ( ! isset( $credentials['connection_type'] ) ) { // All else fails (and it's not defaulted to something else saved), default to FTP.
				$credentials['connection_type'] = 'ftp';
			}

			return $credentials;
		}

		/**
		 * Connect Filesystem API.
		 *
		 * @access private
		 *
		 * @return int connect status: 0 for failure, 1 for success and -1 for try to use native Filesystem API.
		 */
		private function connect_fs() {
			static $connect_st;

			if ( null !== $connect_st ) {
				return $connect_st;
			}

			$connect_st = 0;

			// Need to include file.php for frontend.
			if ( ! function_exists( 'request_filesystem_credentials' ) ) {
				require_once ABSPATH . 'wp-admin/includes/file.php';
			}

			// Check if the user has write permissions.
			$access_type = get_filesystem_method();
			if ( empty( $access_type ) ) {
				$access_type = 'direct';
			}

			// Initialize the Filesystem API.
			if ( ! WP_Filesystem( $this->get_filesystem_credentials( $access_type ) ) ) {
				global $wp_filesystem;
				$connect_st = -1;// Set -1 to allow to use native PHP File.
				// Try to connect Filesystem API again by using method direct to use the native Filesystem API.
				if ( 'direct' !== $access_type && $this->get_module_option( 'use_native_filesystem_api' ) ) {
					if ( $this->enabling_debug_log_mode() && is_wp_error( $wp_filesystem->errors ) && $wp_filesystem->errors->has_errors() ) {
						$error_msg = sprintf( 'Cannot connect to Filesystem API via %1$s: %2$s, trying to use the direct method!', strtoupper( $access_type ), $wp_filesystem->errors->get_error_message() );
					}

					add_filter( 'filesystem_method', array( $this, 'force_access_direct_method' ), 9999 );
					if ( ! WP_Filesystem( true ) ) {
						// This case should be never catch unless file wp-admin/includes/class-wp-filesystem-ftpext.php doesn't exist.
						$connect_st  = 0;
						$this->error = true;
					}
					remove_filter( 'filesystem_method', array( $this, 'force_access_direct_method' ), 9999 );
				} else {
					$connect_st  = 0;
					$this->error = true;
				}

				// Maybe log the error.
				if ( $this->enabling_debug_log_mode() ) {
					// This is for the case we try to use native PHP File handling.
					if ( $this->error && empty( $error_msg ) ) {
						if ( is_wp_error( $wp_filesystem->errors ) && $wp_filesystem->errors->has_errors() ) {
							$error_msg = $wp_filesystem->errors->get_error_message();
						} else {
							/* translators: %s Filesystem method */
							$error_msg = sprintf( 'Connect to the Filesystem API via method %s failure!', strtoupper( $access_type ) );
						}
					}

					if ( ! empty( $error_msg ) ) {
						error_log( $error_msg );// phpcs:ignore.
					}
				}
			} else {
				$connect_st = 1;
			}

			return $connect_st;
		}

		/**
		 * Force set the filesystem method to direct.
		 *
		 * @usedby hook filesystem_method
		 * @see self::connect_fs()
		 *
		 * @return string Direct method.
		 */
		public function force_access_direct_method() {
			return 'direct';
		}

		/**
		 * Prepare filename.
		 *
		 * @access private
		 */
		private function get_file() {
			// Try to get from cache.
			$file = $this->get_module_option( 'file' );
			if ( ! $file ) {
				if ( $this->get_module_option( 'is_private' ) ) {
					$file = 'log.php';
				} else {
					$file = 'debug.log';
				}

				$file_name = $this->get_module_option( 'name' );
				if ( empty( $file_name ) ) {
					$file_name = $this->current_module;
				}
				$file = $file_name . '-' . $file;

				$file = $this->get_log_directory() . $file;

				// Save to module.
				$this->modules[ $this->current_module ]['file'] = $file;
			}

			return apply_filters( 'wdev_logger_get_file', $file, $this->current_module, $this->modules[ $this->current_module ] );
		}

		/**
		 * Get log directory.
		 *
		 * @access private
		 *
		 * @return string
		 */
		private function get_log_directory() {
			$log_dir = WP_CONTENT_DIR . '/' . trailingslashit( $this->get_module_option( 'log_dir' ) );
			if ( ! is_multisite() ) {
				return $log_dir;
			}

			if ( $this->get_module_option( 'add_subsite_dir' ) ) {
				$log_dir .= trailingslashit( preg_replace( '#http(s)?://(www.)?#', '', home_url() ) );
			}
			return $log_dir;
		}

		/**
		 * Check if module should log or not.
		 *
		 * @param mixed  $message Message.
		 * @param string $type Message type: error | warning | notice | info.
		 *
		 * @access private
		 *
		 * @return bool
		 */
		private function should_log( $message, $type ) {
			// We don't log empty message.
			if ( 0 !== $message && empty( $message ) ) {
				return false;
			}
			// Stop if there is any errors occur.
			if ( $this->error ) {
				// Log error.
				if ( $this->enabling_debug_log_mode() && is_wp_error( $this->error ) ) {
					error_log( $this->error->get_error_message() );// phpcs:ignore.
				}
				return false;
			}
			// Make sure we connected to Filesystem API.
			if ( ! $this->connect_fs() || ! $this->is_writable_log_dir() ) {
				if ( $this->enabling_debug_log_mode() ) {
					$error = error_get_last();
					if ( ! empty( $error['message'] ) ) {
						error_log( $error['message'] );// phpcs:ignore.
					}
				}
				return false;
			}

			$do_log = $this->get_log_level();
			if ( $do_log && is_int( $do_log ) ) {
				$do_log = $this->level_can_do( $this->log_level, $type, $do_log );
			}

			return apply_filters( 'wdev_logger_should_log', $do_log, $this->current_module, $message );
		}

		/**
		 * Detect if the current log level can do something.
		 *
		 * @access private
		 *
		 * @param int    $level Level number, it can be: LOG_ERR | LOG_WARNING | LOG_NOTICE | LOG_INFO | LOG_DEBUG OR self::WPMUDEV_DEBUG_LEVEL.
		 * @param string $type Message type.
		 * @param bool   $can_do Default value.
		 * @return bool
		 */
		private function level_can_do( $level, $type, $can_do = false ) {
			$checking_debug_log_level = $can_do;
			if ( $type && is_string( $type ) ) {
				$type = strtolower( $type );
				switch ( $level ) {
					case LOG_DEBUG:
						$can_do = 'error' === $type || 'warning' === $type || 'notice' === $type;
						break;
					case LOG_ERR:
						$can_do = 'error' === $type;
						break;
					case LOG_WARNING:
						$can_do = 'warning' === $type;
						break;
					case LOG_NOTICE:
						$can_do = 'notice' === $type;
						break;
					case LOG_INFO:
						$can_do = 'info' === $type;
						break;
					case self::WPMUDEV_DEBUG_LEVEL:
						$can_do = true;
						break;
				}
			}
			return apply_filters( 'wdev_logger_level_can_do', $can_do, $level, $type, $checking_debug_log_level );
		}

		/**
		 * Check if log directory is already create, if not - create it.
		 *
		 * @access private
		 */
		private function is_writable_log_dir() {
			global $wp_filesystem;

			$log_dir = dirname( $this->get_file() );

			$exist_and_writable = 0;
			if ( $wp_filesystem->is_dir( $log_dir ) ) {
				if ( $wp_filesystem->is_writable( $log_dir ) || $wp_filesystem->chmod( $log_dir, FS_CHMOD_DIR ) ) {
					return true;
				}
			} elseif ( $status = $this->create_log_dir( $log_dir ) ) {//phpcs:ignore
				if ( true === $status ) {
					$wp_filesystem->put_contents( $log_dir . '/index.php', '<?php' . PHP_EOL . '// Silence is golden.', FS_CHMOD_FILE );
				}
				$exist_and_writable = 1;
			}
			return $exist_and_writable;
		}

		/**
		 * Create the log directory.
		 *
		 * @param string $log_dir Log dir.
		 * @return bool True on success, false on failure.
		 */
		public function create_log_dir( $log_dir ) {
			if ( ! mkdir( $log_dir, FS_CHMOD_DIR, true ) ) {
				global $wp_filesystem;
				$log_dir = str_replace( '\\', '/', $log_dir );
				$log_dir = trailingslashit( $log_dir );
				$offset  = strlen( WP_CONTENT_DIR );
				if ( $pos = strpos( $log_dir, '/', $offset ) ) {//phpcs:ignore
					while ( $pos ) {
						$n_log_dir = substr( $log_dir, 0, $pos );
						if ( ! $wp_filesystem->is_dir( $n_log_dir ) ) {
							if ( $wp_filesystem->mkdir( $n_log_dir ) ) {
								$wp_filesystem->put_contents( $log_dir . '/index.php', '<?php' . PHP_EOL . '// Silence is golden.', FS_CHMOD_FILE );
							} else {
								return false;
							}
						}
						$offset = $pos + 1;
						$pos    = strpos( $log_dir, '/', $offset );
					}

					return 1;
				}
				return $wp_filesystem->mkdir( $log_dir );
			} else {
				return true;
			}
		}

		/**
		 * Attempt to write file.
		 *
		 * @access private
		 *
		 * @param  string $message  String to write to file.
		 */
		private function write_log_file( $message = '' ) {
			global $wp_filesystem;

			// Append a new blank line.
			$message = trim( $message ) . PHP_EOL;

			$file = $this->get_file();

			// Disable access the private file directly.
			if ( $this->get_module_option( 'is_private' ) && ! $wp_filesystem->exists( $file ) ) {
				$message = '<?php die(); ?>' . PHP_EOL . $message;
			}

			/**
			 * By default, we will try to append the message to the log file.
			 * Add a filter to allow third-party doing it by their self.
			 */
			$check = apply_filters( 'wdev_logger_update_file', null, $file, $message, $this->current_module );
			if ( null !== $check ) {
				return (bool) $check;
			}

			// Try to use append method before using put_contents.
			switch ( $wp_filesystem->method ) {
				case 'ssh2':
					$file = $wp_filesystem->sftp_path( $file );
					// continue to use direct method.
				case 'direct':
					// Append message to the log file.
					$ret = file_put_contents( $file, $message, FILE_APPEND | LOCK_EX );

					if ( strlen( $message ) !== $ret ) {
						return false;
					}
					break;
				case 'ftpext':
					if ( function_exists( 'ftp_append' ) ) {
						$tempfile   = wp_tempnam( $file );
						$temphandle = fopen( $tempfile, 'wb+' );

						if ( ! $temphandle ) {
							unlink( $tempfile );
							return false;
						}

						mbstring_binary_safe_encoding();

						$data_length   = strlen( $message );
						$bytes_written = fwrite( $temphandle, $message );

						reset_mbstring_encoding();

						if ( $data_length !== $bytes_written ) {
							fclose( $temphandle );
							unlink( $tempfile );
							return false;
						}

						fseek( $temphandle, 0 ); // Skip back to the start of the file being written to.

						$ret = ftp_append( $wp_filesystem->link, $file, $tempfile, FTP_BINARY );

						fclose( $temphandle );
						unlink( $tempfile );
						break;
					}
					// continue to use default option.
				default:
					$contents = '';
					if ( $wp_filesystem->exists( $file ) ) {
						$contents = $wp_filesystem->get_contents( $file );
					}
					$contents .= $message;
					return $wp_filesystem->put_contents( $file, $contents, FS_CHMOD_FILE );
			}

			// chmod file.
			$wp_filesystem->chmod( $file, FS_CHMOD_FILE );

			return $ret;
		}

		/**
		 * Set current module.
		 *
		 * @access private
		 *
		 * @param string $module Module name.
		 */
		private function set_current_module( $module ) {
			$set = 0;
			if ( ! empty( $module ) && isset( $this->modules[ $module ] ) ) {
				$set = -1;
				if ( $module !== $this->current_module ) {
					$this->current_module = $module;
					// Reset debug/log level.
					$this->log_level   = null;
					$this->debug_level = null;
					$set               = 1;
				}
			}

			return $set;
		}

		/**
		 * Set current module.
		 *
		 * @param string $module Module name.
		 *
		 * @return true;
		 */
		public function register_module( $module ) {
			if ( $module ) {
				$module = str_replace( '-', '_', sanitize_key( $module ) );
			}
			if ( ! $this->set_current_module( $module ) ) {
				$this->maybe_active_global_module();
			}
			return true;
		}

		/**
		 * Allow call the log actions directly from the original instance.
		 * $logger->error('Something here');
		 * $logger->log('Something here');
		 *
		 * @param bool $return Return a instance of WP_Error
		 * or exit if we can't detect the global module.
		 */
		public function maybe_active_global_module( $return = false ) {
			if ( ! $this->un_lock ) {
				if ( ! ( isset( $this->option['global_module'] ) && $this->set_current_module( $this->option['global_module'] ) ) ) {
					if ( $return ) {
						return new WP_Error( 'non-registered', 'Cheating, huh?' );
					} else {
						wp_die( 'Cheating, huh?' );
					}
				}
			} else {
				// re-lock.
				$this->un_lock = false;
			}
		}

		/**
		 * Set a schedule to clean the logs.
		 */
		public function check_cron_schedule() {
			if ( ! wp_next_scheduled( 'wdev_logger_clear_logs' ) ) {
				wp_schedule_event( strtotime( 'midnight' ), 'daily', 'wdev_logger_clear_logs' );
			}
		}

		/**
		 * Get rid of the old messages that take the file size over the maximum log file size.
		 * We will reduce the file size to the expected size.
		 * Expected size = max_log_size * expected_log_size_in_percent
		 */
		public function clear_logs() {
			if ( ! empty( $this->modules ) && $this->connect_fs() ) {
				global $wp_filesystem;
				foreach ( $this->modules as $module => $module_option ) {
					$this->set_current_module( $module );
					$file = $this->get_file();
					if ( $wp_filesystem->exists( $file ) ) {
						// Delete the log file if deactivated debug log.
						if ( ! $this->get_log_level() ) {
							$wp_filesystem->delete( $file, false, 'f' );
							continue;
						}

						$file_size     = $wp_filesystem->size( $file );
						$max_file_size = $this->get_module_option( 'max_log_size' ) * MB_IN_BYTES;
						if ( $file_size < $max_file_size ) {
							continue;
						}
						$expected_file_size = $this->get_module_option( 'expected_log_size_in_percent' ) * $max_file_size;
						if ( $expected_file_size < 1 ) {
							$wp_filesystem->delete( $file, false, 'f' );
							continue;
						}
						$contents = $wp_filesystem->get_contents( $file );
						$offset   = intval( $file_size - $expected_file_size );
						$pos      = strpos( $contents, PHP_EOL . '[', $offset );
						if ( ! $pos ) {
							$pos = strpos( $contents, PHP_EOL, $offset );
						}
						if ( $pos ) {
							$contents = substr( $contents, $pos );
							if ( $this->get_module_option( 'is_private' ) ) {
								$contents = '<?php die(); ?>' . $contents;
							}
							$wp_filesystem->put_contents( $file, $contents, FS_CHMOD_FILE );
						} else {
							$wp_filesystem->delete( $file, false, 'f' );
						}
					}
				}
			}
		}

	}
}
