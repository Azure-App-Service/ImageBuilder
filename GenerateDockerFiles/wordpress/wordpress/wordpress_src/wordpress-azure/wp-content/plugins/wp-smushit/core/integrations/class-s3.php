<?php
/**
 * S3 integration: S3 class
 *
 * Minimum supported version - Offload Media 2.4
 *
 * @package Smush\Core\Modules\Integrations
 * @subpackage S3
 * @since 2.7
 *
 * @author Umesh Kumar <umesh@incsub.com>
 *
 * @copyright (c) 2017, Incsub (http://incsub.com)
 */

namespace Smush\Core\Integrations;

use Amazon_S3_And_CloudFront;
use DeliciousBrains\WP_Offload_Media\Items\Media_Library_Item;
use Smush\App\Admin;
use Smush\Core\Settings;
use Smush\Core\Helper;
use WP_Smush;

if ( ! defined( 'WPINC' ) ) {
	die;
}

/**
 * Class S3
 */
class S3 extends Abstract_Integration {

	/**
	 * Save list of files need to remove
	 * when user enabling "Remove Files From Server".
	 *
	 * @var array
	 */
	private $files_to_remove = array();

	/**
	 * Cache list of files download failed.
	 *
	 * @var array
	 */
	private $files_download_failed = array();

	/**
	 * On Smush mode, we will disable auto download and auto-upload
	 * while working with Smush.
	 *
	 * @var boolean
	 */
	private $on_smush_mode;

	/**
	 * Cache list of files to delete via remove_file method.
	 *
	 * @var array
	 */
	private $doing_files;

	/**
	 * Cache list of filters for get_attached_file.
	 *
	 * @var null|array
	 */
	private $list_file_filters;

	/**
	 * S3 constructor.
	 */
	public function __construct() {
		$this->module  = 's3';
		$this->class   = 'pro';
		$this->enabled = function_exists( 'as3cf_init' ) || function_exists( 'as3cf_pro_init' );

		parent::__construct();

		// Hook at the end of setting row to output a error div.
		add_action( 'smush_setting_column_right_inside', array( $this, 's3_setup_message' ), 15 );

		// Show S3 integration message, if user hasn't enabled it.
		add_action( 'wp_smush_header_notices', array( $this, 'show_s3_support_required_notice' ) );

		// Add Pro tag.
		if ( ! WP_Smush::is_pro() || ! $this->enabled ) {
			add_action( 'smush_setting_column_tag', array( $this, 'add_pro_tag' ) );
		}

		// Do not continue if not enabled or S3 Offload plugin is not installed.
		if ( ! $this->is_active() ) {
			return;
		}

		// Load all our custom actions/filters after loading as3cf.
		if ( did_action( 'as3cf_init' ) ) {
			$this->init();
		} else {
			add_action( 'as3cf_init', array( $this, 'init' ) );
		}
	}

	/**
	 * Register actions, filters for S3.
	 *
	 * @since 3.9.6
	 */
	public function init() {
		global $as3cf;

		// Check file exists.
		add_filter( 'wp_smush_file_exists', array( $this, 'file_exists_on_s3' ), 10, 4 );

		// Get attached file.
		add_filter( 'wp_smush_get_attached_file', array( $this, 'get_attached_file' ), 10, 5 );

		// Check unique file with the backup file.
		add_filter( 'wp_unique_filename', array( $this, 'filter_unique_filename' ), 99, 3 );// S3 is using priority 10.

		// Check if the file exists for the given path and download.
		add_action( 'wp_smush_before_restore_backup', array( $this, 'maybe_download_file' ), 10, 2 );
		// Update original source path of as3cf_items after converting PNG to JPG.
		add_action( 'wp_smush_image_url_changed', array( $this, 'update_original_source_path_after_png2jpg' ), 10, 4 );
		// Update original source path of as3cf_items after restore the converted PNG2JPG file.
		add_action( 'wp_smush_image_url_updated', array( $this, 'update_original_source_path_after_restore_png' ), 10, 3 );

		// If user is enabling copy to S3.
		if ( $as3cf->get_setting( 'copy-to-s3' ) ) {
			/**
			 * Activate Smush mode (Disable auto download and upload attachments).
			 *
			 * Note, we managed to release this mode by using Helper::wp_update_attachment_metadata() or
			 * via action "wp_smush_after_smush_file"
			 */
			// Activate smush mode before smushing/restoring.
			add_action( 'wp_smush_before_smush_file', array( $this, 'activate_smush_mode' ), 1 );
			add_action( 'wp_smush_before_restore_backup', array( $this, 'activate_smush_mode' ), 1 );

			/**
			 * When WP create a new attachment, S3 will try to upload it to the server,
			 * and then it will upload the thumbnails later after regenerating the thumbnails.
			 * So we use this filter to temporary disable upload if smush can do with this file.
			 *
			 * Note, if we don't work with the current image, e.g animated file,
			 * we managed to release this mode by using maybe_release_smush_mode.
			 */
			add_filter( 'wp_update_attachment_metadata', array( $this, 'maybe_active_smush_mode' ), 1, 2 );

			// Reset smush mode after smushing/restoring.
			add_action( 'wp_smush_after_smush_file', array( $this, 'release_smush_mode' ) );
			add_action( 'wp_smush_after_restore_backup', array( $this, 'release_smush_mode' ) );
			/**
			 * Make sure we exit Smush mode before updating the metadata,
			 * this will help we to upload the attachments, and remove them if it's required.
			 */
			add_action( 'wp_smush_before_update_attachment_metadata', array( $this, 'release_smush_mode' ) );
			// Release mode when we don't smush the image.
			add_action( 'wp_smush_no_smushit', array( $this, 'maybe_release_smush_mode' ) );

			// Remove .bak file after restoring, and JPG files after restoring PNG file.
			add_action( 'wp_smush_after_remove_file', array( $this, 'remove_file' ), 10, 3 );
			// Make sure we removed all downloaded files.
			add_filter( 'shutdown', array( $this, 'maybe_remove_downloaded_files' ), 10, 2 );
		}
	}

	/**************************************
	 *
	 * OVERWRITE PARENT CLASS FUNCTIONALITY
	 */

	/**
	 * Filters the setting variable to add S3 setting title and description.
	 *
	 * @param array $settings  Settings array.
	 *
	 * @return array
	 */
	public function register( $settings ) {
		$plugin_url                = esc_url( 'https://wordpress.org/plugins/amazon-s3-and-cloudfront/' );
		$settings[ $this->module ] = array(
			'label'       => __( 'Enable Amazon S3 support', 'wp-smushit' ),
			'short_label' => __( 'Amazon S3', 'wp-smushit' ),
			'desc'        => sprintf( /* translators: %1$s - <a>, %2$s - </a> */
				esc_html__(
					"Storing your image on S3 buckets using %1\$sWP Offload Media%2\$s? Smush can detect
				and smush those assets for you, including when you're removing files from your host server.",
					'wp-smushit'
				),
				"<a href='$plugin_url' target = '_blank'>",
				'</a>'
			),
		);

		return $settings;
	}

	/**************************************
	 *
	 * PUBLIC CLASSES
	 */

	/**
	 * Check if the file is served by S3 and download the file for given path
	 *
	 * @param string $file_path      Full file path.
	 * @param string $attachment_id  Attachment ID.
	 *
	 * @return bool|string False/ File Path
	 */
	public function maybe_download_file( $file_path, $attachment_id ) {
		// Download the backup file if it doesn't exist on the server.
		return $this->download_file( $file_path, $attachment_id );
	}

	/**
	 * Checks if the given attachment is on S3 or not, Returns S3 URL or WP Error
	 *
	 * @param string $attachment_id  Attachment ID.
	 *
	 * @return bool
	 */
	public function is_image_on_s3( $attachment_id = '' ) {
		if ( empty( $attachment_id ) ) {
			return false;
		}

		// If the file path contains S3, get the s3 URL for the file.
		if ( function_exists( 'as3cf_get_attachment_url' ) ) {
			return as3cf_get_attachment_url( $attachment_id );
		}

		Helper::logger()->integrations()->error( 'S3 - Function as3cf_get_attachment_url does not exists.' );
		return false;
	}

	/**
	 * Checks if file exits on S3.
	 *
	 * @param bool   $exists           If file exists on S3.
	 * @param mixed  $file_path        File path or empty value.
	 * @param string $attachment_id    Attachment ID.
	 * @param bool   $should_download  Should download attachment.
	 *
	 * @return bool|string Returns TRUE OR File path if it exists, FALSE otherwise.
	 */
	public function file_exists_on_s3( $exists, $file_path, $attachment_id, $should_download ) {
		if ( ! $exists ) {
			if ( empty( $file_path ) ) {
				// Maybe file is not uploaded to provider, try to get the raw file path.
				$file_path = $this->get_raw_attached_file( $attachment_id );
			}
			$exists = file_exists( $file_path );
		}

		if ( ! $exists ) {
			if ( $should_download ) {
				$exists = $this->download_file( $file_path, $attachment_id );
			} else {
				$exists = $this->does_image_exists( $attachment_id, $file_path );
			}
		}

		return $exists;
	}

	/**
	 * Error message to show when S3 support is required.
	 *
	 * Show a error message to admins, if they need to enable S3 support. If "remove files from
	 * server" option is enabled in WP Offload Media plugin, we need WP Smush Pro to enable S3 support.
	 */
	public function show_s3_support_required_notice() {
		// Do not display it for other users. Do not display on network screens, if network-wide option is disabled.
		if ( ! current_user_can( 'manage_options' ) || ! Settings::can_access( 'integrations' ) ) {
			return;
		}

		// Do not display the notice on Bulk Smush Screen.
		global $current_screen;

		if ( ! empty( $current_screen->id ) && ! in_array( $current_screen->id, Admin::$plugin_pages, true ) && false === strpos( $current_screen->id, 'page_smush' ) ) {
			return;
		}

		// If already dismissed, do not show.
		if ( '1' === get_site_option( 'wp-smush-hide_s3support_alert' ) ) {
			return;
		}

		// Return early, if support is not required.
		if ( ! $this->s3_support_required() ) {
			return;
		}

		// Settings link.
		$settings_link = is_multisite() && is_network_admin()
			? network_admin_url( 'admin.php?page=smush-integrations' )
			: menu_page_url( 'smush-integrations', false );

		if ( WP_Smush::is_pro() ) {
			/**
			 * If premium user, but S3 support is not enabled.
			 */
			$message = sprintf(
				/* Translators: %1$s: opening strong tag, %2$s: closing strong tag, %s: settings link, %3$s: opening a and strong tags, %4$s: closing a and strong tags */
				__(
					'We can see you have WP Offload Media installed with the %1$sRemove Files From Server%2$s option activated. If you want to optimize your S3 images, you’ll need to enable the %3$sAmazon S3 Support%4$s feature in Smush’s Integrations.',
					'wp-smushit'
				),
				'<strong>',
				'</strong>',
				"<a href='$settings_link'><strong>",
				'</strong></a>'
			);
		} else {
			/**
			 * If not a premium user.
			 */
			$message = sprintf(
				/* Translators: %1$s: opening strong tag, %2$s: closing strong tag, %s: settings link, %3$s: opening a and strong tags, %4$s: closing a and strong tags */
				__(
					"We can see you have WP Offload Media installed with the %1\$sRemove Files From Server%2\$s option activated. If you want to optimize your S3 images you'll need to %3\$supgrade to Smush Pro%4\$s",
					'wp-smushit'
				),
				'<strong>',
				'</strong>',
				'<a href=' . esc_url( 'https://wpmudev.com/project/wp-smush-pro' ) . '><strong>',
				'</strong></a>'
			);
		}
		$message = '<p>' . $message . '</p>';
		echo '<div role="alert" id="wp-smush-s3support-alert" class="sui-notice" data-message="' . esc_attr( $message ) . '" aria-live="assertive"></div>';
	}

	/**
	 * Prints the message for S3 setup
	 *
	 * @param string $setting_key  Settings key.
	 */
	public function s3_setup_message( $setting_key ) {
		// Return if not S3.
		if ( $this->module !== $setting_key ) {
			return;
		}

		/**
		 * Amazon_S3_And_CloudFront global.
		 *
		 * @var Amazon_S3_And_CloudFront $as3cf
		 */
		global $as3cf;

		// If S3 integration is not enabled, return.
		$setting_val = WP_Smush::is_pro() ? $this->settings->get( $this->module ) : 0;

		// If integration is disabled when S3 offload is active, do not continue.
		if ( ! $setting_val && is_object( $as3cf ) ) {
			return;
		}

		// If S3 offload global variable is not available, plugin is not active.
		if ( ! is_object( $as3cf ) ) {
			$class   = '';
			$message = __( 'To use this feature you need to install WP Offload Media and have an Amazon S3 account setup.', 'wp-smushit' );
		} elseif ( ! method_exists( $as3cf, 'is_plugin_setup' ) || ! method_exists( $as3cf, 'get_plugin_page_url' ) ) {
			// Check if in case for some reason, we couldn't find the required function.
			$class   = ' sui-notice-warning';
			$message = sprintf( /* translators: %1$s: opening a tag, %2$s: closing a tag */
				esc_html__(
					'We are having trouble interacting with WP Offload Media, make sure the plugin is activated. Or you can %1$sreport a bug%2$s.',
					'wp-smushit'
				),
				'<a href="' . esc_url( 'https://wpmudev.com/contact' ) . '" target="_blank">',
				'</a>'
			);
		} elseif ( ! $as3cf->is_plugin_setup() ) {
			// Plugin is not setup, or some information is missing.
			$class   = ' sui-notice-warning';
			$message = sprintf( /* translators: %1$s: opening a tag, %2$s: closing a tag */
				esc_html__(
					'It seems you haven’t finished setting up WP Offload Media yet. %1$sConfigure it now%2$s to enable Amazon S3 support.',
					'wp-smushit'
				),
				'<a href="' . $as3cf->get_plugin_page_url() . '" target="_blank">',
				'</a>'
			);
		} else {
			// S3 support is active.
			$class   = ' sui-notice-info';
			$message = __( 'Amazon S3 support is active.', 'wp-smushit' );
		}
		?>
		<div class="sui-toggle-content">
			<div class="sui-notice<?php echo esc_attr( $class ); ?>">
				<div class="sui-notice-content">
					<div class="sui-notice-message">
						<i class="sui-notice-icon sui-icon-info" aria-hidden="true"></i>
						<p><?php echo wp_kses_post( $message ); ?></p>
					</div>
				</div>
			</div>
		</div>
		<?php
	}

	/**
	 * Add a pro tag next to the setting title.
	 *
	 * @param string $setting_key  Setting key name.
	 *
	 * @since 3.4.0
	 */
	public function add_pro_tag( $setting_key ) {
		// Return if not NextGen integration.
		if ( $this->module !== $setting_key || WP_Smush::is_pro() ) {
			return;
		}
		?>
		<span class="sui-tag sui-tag-pro">
			<?php esc_html_e( 'Pro', 'wp-smushit' ); ?>
		</span>
		<?php
	}

	/**
	 * Disable auto downloading the file to local while Smush doing, only allow it with our custom methods:
	 * Helper::get_attached_file( $attachment_id, $type='smush|resize|original')
	 * or Helper::exists_or_downloaded( $file, $attachment_id ),
	 * and set wait_for_generate_attachment_metadata is TRUE to disable auto upload attachments while
	 * we are working with it.
	 *
	 * @since 3.4.0
	 *
	 * @since 3.9.6
	 * Enable copy file back to local and wait_for_generate_attachment_metadata while we working with smush or restore.
	 */
	public function activate_smush_mode() {
		if ( $this->is_active() && ! $this->on_smush_mode ) {
			global $as3cf;
			// Save mode.
			$this->on_smush_mode = true;
			/**
			 * Disable auto download to local, we only enable it via  self::downoad_file method to avoid automatic download link.
			 * e.g. wp_attachment_is_image()
			 */
			add_filter( 'as3cf_get_attached_file_copy_back_to_local', '__return_false', 9998 );
			// Disable auto upload attachments.
			add_filter( 'as3cf_wait_for_generate_attachment_metadata', '__return_true', 9998 );

			// If user enabling remove file on local.
			if ( $as3cf && $as3cf->get_setting( 'remove-local-file' ) ) {
				// We don't remove the filter because it might be called later.
				add_filter( 'as3cf_upload_attachment_local_files_to_remove', array( $this, 'remove_missing_files_to_avoid_error_log_from_s3' ), 99 );
			}
		}
	}

	/**
	 * Set Smush mode while creating a new image.
	 *
	 * @param array $image_meta Image meta.
	 * @param int   $attachment_id Attachment ID.
	 * @return array The provided metadata.
	 */
	public function maybe_active_smush_mode( $image_meta, $attachment_id ) {
		if (
			! $this->on_smush_mode
			// When async uploading or the image is created from Gutenberg, activate smush mode.
			&& empty( $new_meta['sizes'] )
			&& ! empty( $image_meta['file'] )
			// phpcs:ignore
			&& ( isset( $_POST['post_id'] ) || isset( $_FILES['async-upload'] ) || ! Helper::is_non_rest_media() )
			// If enabling auto-smush.
			&& $this->settings->get( 'auto' )
			// Managed it.
			&& ! did_action( 'wp_smush_before_smush_file' )
			// Managed it.
			&& ! did_action( 'wp_smush_before_restore_backup' )
			// Managed it.
			&& ! did_action( 'wp_smush_before_update_attachment_metadata' )
			// Don't smush it.
			&& ! did_action( 'wp_smush_no_smushit' )
			// Only support Image.
			&& Helper::is_smushable( $attachment_id )
			// Make sure we only disable while async upload new image.
			&& ! $this->does_image_exists( $attachment_id, $this->get_raw_attached_file( $attachment_id, 'original' ) )
		) {
			$this->activate_smush_mode();
		}

		return $image_meta;
	}

	/**
	 * If we don't work with current image,
	 * make sure we released Smush mode which set by maybe_active_smush_mode.
	 *
	 * @param int $attachment_id Attachment ID.
	 */
	public function maybe_release_smush_mode( $attachment_id ) {
		// Release smush mode.
		$this->release_smush_mode();

		if ( WP_SMUSH_ASYNC && $this->settings->get( 'auto' ) && doing_filter( 'wp_async_wp_generate_attachment_metadata' ) ) {
			// Make sure all images will upload to cloud.
			if ( ! did_action( 'wp_smush_before_update_attachment_metadata' ) && ! did_action( 'wp_smush_before_restore_backup' ) ) {
				global $as3cf;
				// Make sure method exits.
				if ( ! method_exists( $as3cf, 'upload_attachment' ) ) {
					Helper::logger()->integrations()->error( 'S3 - Method $as3cf->upload_attachment() does not exists.' );
					return;
				}
				if ( $as3cf->get_setting( 'copy-to-s3' )
					&& ! $this->does_image_exists( $attachment_id, $this->get_raw_attached_file( $attachment_id, 'original' ) ) ) {
					$as3cf->upload_attachment( $attachment_id, wp_get_attachment_metadata( $attachment_id ) );
				}
			}
		}
	}

	/**
	 * Release all our configs for copy file back to local
	 * and wait_for_generate_attachment_metadata before calling
	 * wp_update_attachment_metadata
	 *
	 * @since 3.9.6
	 */
	public function release_smush_mode() {
		if ( $this->is_active() && $this->on_smush_mode ) {
			remove_filter( 'as3cf_get_attached_file_copy_back_to_local', '__return_false', 9998 );
			remove_filter( 'as3cf_wait_for_generate_attachment_metadata', '__return_true', 9998 );
			// Reset mode.
			$this->on_smush_mode = false;
		}
	}

	/**
	 * Download file back to the server if missing when get_attached_file() is called.
	 *
	 * @since 3.9.6
	 *
	 * @param null|string $file_path        File path or file url(checking resize).
	 * @param int         $attachment_id    Attachment ID.
	 * @param bool        $should_download  Should download the file if it doesn't exist.
	 * @param bool        $should_real_path Expecting a real file path instead an URL.
	 * @param string      $type             original|smush|backup|resize.
	 *
	 * @return string     File path or S3 url.
	 */
	public function get_attached_file( $file_path, $attachment_id, $should_download, $should_real_path, $type ) {
		if ( is_null( $file_path ) ) {
			// Try to get crawl file path.
			$file_path = $this->get_raw_attached_file( $attachment_id, $type );
			if ( file_exists( $file_path ) ) {
				return $file_path;
			} else {
				if ( $should_download ) {
					$downloaded_file_path = $this->download_file( $file_path, $attachment_id );
					if ( $downloaded_file_path ) {
						$file_path = $downloaded_file_path;
					}
				} elseif ( ! $should_real_path ) {
					// Try to get S3 url.
					$file_path = apply_filters( 'get_attached_file', $file_path, $attachment_id );
				}
			}
		}
		return $file_path;
	}

	/**
	 * Delete multiple objects.
	 *
	 * @param array $objects_to_remove Objects to remove.
	 */
	private function delete_objects( $objects_to_remove ) {
		$provider_client = $this->get_provider_client();
		if ( $provider_client && method_exists( $provider_client, 'delete_objects' ) ) {
			global $as3cf;
			return $provider_client->delete_objects(
				array(
					'Bucket' => $as3cf->get_setting( 'bucket' ),
					'Delete' => array(
						'Objects' => $objects_to_remove,
					),
				)
			);
		} else {
			Helper::logger()->integrations()->error( 'S3 - AWS_Provider->delete_objects does not exist.' );
		}
		return false;
	}

	/**
	 * Remove the backup file and JPG files (PNG2JPG) from S3 when image is restored.
	 *
	 * @since 3.8.4
	 *
	 * @since 3.9.6 Remove file(s) from S3.
	 *
	 * @param int    $attachment_id  Attachment ID.
	 * @param string $file_paths      File path(s).
	 * @param bool   $removed        Whether the provided files are removed or not.
	 */
	public function remove_file( $attachment_id, $file_paths, $removed ) {
		// Returns if file path is empty.
		if ( empty( $attachment_id ) || empty( $file_paths ) ) {
			return false;
		}
		/**
		 * Amazon_S3_And_CloudFront global.
		 *
		 * @var Amazon_S3_And_CloudFront $as3cf
		 */
		global $as3cf;

		// Get s3 object for the file.
		if ( ! $s3_object = $this->is_attachment_served_by_provider( $as3cf, $attachment_id ) ) {
			return false;
		}

		$file_paths = (array) $file_paths;

		// Get file key.
		$is_object         = is_object( $s3_object );
		$objects_to_remove = array();
		if ( $is_object && $s3_object instanceof Media_Library_Item && method_exists( $s3_object, 'key' ) ) {
			/**
			 * We use this method to support private mode too.
			 *
			 * @see Media_Library_Item()->key() (>=2.4)
			 */
			foreach ( $file_paths as $size_key => $file_path ) {
				if ( ! $removed && file_exists( $file_path ) ) {
					@unlink( $file_path );// phpcs:ignore.
				}

				$objects_to_remove[] = array(
					'Key' => $this->get_object_key( $s3_object, $file_path, $size_key ),
				);
			}
		} else {
			// Try with the old version.
			if ( $is_object ) {
				$key = $s3_object->path();
			} else {
				$key = $s3_object['key'];
			}

			$size_prefix      = dirname( $key );
			$size_file_prefix = ( '.' === $size_prefix ) ? '' : $size_prefix . '/';

			foreach ( $file_paths as $file_path ) {
				if ( ! $removed && file_exists( $file_path ) ) {
					@unlink( $file_path );// phpcs:ignore.
				}
				// Get the File path using basename for given attachment path.
				$objects_to_remove[] = array(
					'Key' => path_join( $size_file_prefix, wp_basename( $file_path ) ),
				);
			}
		}

		return $this->delete_objects( $objects_to_remove );
	}

	/**
	 * Add a filter before wp_update_attachment_metadata
	 * to remove skipped thumbnails from s3 upload.
	 *
	 * @since 3.9.6
	 */
	public function maybe_remove_sizes_from_s3_upload() {
		/**
		 * When S3 integration is enabled, the wp_update_attachment_metadata below will trigger the
		 * wp_update_attachment_metadata filter WP Offload Media, which in turn will try to re-upload all the files
		 * to an S3 bucket. But, if some sizes are skipped during Smushing, WP Offload Media will print error
		 * messages to debug.log. This will help avoid that.
		 *
		 * @since 3.0
		 *
		 * @since 3.9.6 Moved it from Smush\Core\Modules\Smush to S3
		 */
		add_filter( 'as3cf_attachment_file_paths', array( $this, 'remove_sizes_from_s3_upload' ), 10, 3 );
	}

	/**
	 * Remove all downloaded files
	 * if user enabling "Remove Files From Server".
	 *
	 * @since 3.9.6
	 *
	 * Note, we will remove all images that saved in variable $this->files_to_remove
	 * so please check member enabling "Remove Files From Server" before adding the image.
	 */
	public function maybe_remove_downloaded_files() {
		if ( $this->is_active() ) {
			global $as3cf;
			if ( isset( $this->files_to_remove ) && $as3cf && $as3cf->get_setting( 'remove-local-file' ) ) {
				foreach ( $this->files_to_remove  as $file_path ) {
					if ( file_exists( $file_path ) ) {
						unlink( $file_path );
					}
				}
			}
		}
	}

	/**
	 * Verify the unique file name with the backup file of PNG2JPG file.
	 *
	 * E.g
	 * If member enable "remove file from local", the uploads folder will be empty,
	 * so WP core will not handle this case, S3 only handle the main file and the sub-sizes.
	 * => In order to avoid conflicts, when generate a new unique file, we also need to check if it is a backed up file or not.
	 * What we are expecting is:
	 * 1. Image 1 test.png => test.jpg + backup file test.png
	 * 2. Image 2 test.png => test-1.jpg + backup file test-1.png not test.png
	 *
	 * @param string $filename Unique file name.
	 * @param string $ext      File extension, eg. ".png".
	 * @param string $dir      Directory path.
	 *
	 * @return string
	 */
	public function filter_unique_filename( $filename, $ext, $dir ) {
		// Only check for PNG type and activating backup mode.
		if ( '.png' === $ext && WP_Smush::get_instance()->core()->mod->png2jpg->is_active() ) {
			global $as3cf;
			if ( method_exists( $as3cf, 'does_file_exist' ) ) {
				$uploads  = wp_upload_dir();
				$basedir  = trailingslashit( $uploads['basedir'] );
				$count    = 0;
				$name     = pathinfo( $filename, PATHINFO_FILENAME );
				$filename = $name . $ext;
				$time     = current_time( 'mysql' );
				while ( ( $count && $as3cf->does_file_exist( $filename, $time ) ) || $this->is_png2jpg_backup_file( $filename, $dir, $basedir ) ) {
					$count++;
					$filename = $name . '-' . $count . $ext;
				}
				return $filename;
			} else {
				Helper::logger()->integrations()->error( 'S3 - Method $as3cf->does_file_exist() does not exists.' );
			}
		}
		return $filename;
	}

	/**
	 * Get unique PNG file name by verify the backup file.
	 * file name
	 *
	 * @param  string $filename  Unique file name.
	 * @param  string $dir       Directory path.
	 * @param  string $basedir   Base upload directory.
	 * @return string Unique PNG file name.
	 */
	private function is_png2jpg_backup_file( $filename, $dir, $basedir ) {
		$backup    = WP_Smush::get_instance()->core()->mod->backup;
		$file_path = substr( path_join( $dir, pathinfo( $filename, PATHINFO_FILENAME ) . '.jpg' ), strlen( $basedir ) );
		// Get s3_object_item from jpg file.
		$jpg_items = Media_Library_Item::get_by_source_path( $file_path, array(), true, true );
		if ( ! empty( $jpg_items ) ) {
			foreach ( $jpg_items as $jpg_item ) {
				$jpg_id       = $jpg_item->source_id();
				$backup_sizes = $backup->get_backup_sizes( $jpg_id );
				// If the current file is the same as the backup file, try to get a unique file name.
				if ( $backup_sizes && isset( $backup_sizes['smush-full']['file'] ) && $backup_sizes['smush-full']['file'] === $filename ) {
					return true;
				}
			}
		}

		return false;
	}

	/**
	 * Remove paths that should not be re-uploaded to an S3 bucket.
	 *
	 * See as3cf_attachment_file_paths filter description for more information.
	 *
	 * @since 3.0
	 *
	 * @param array $paths          Paths to be uploaded to S3 bucket.
	 * @param int   $attachment_id  Attachment ID.
	 * @param array $meta           Image metadata.
	 *
	 * @since 3.9.6 Moved it from Smush\Core\Modules\Smush to S3
	 *
	 * @return mixed
	 */
	public function remove_sizes_from_s3_upload( $paths, $attachment_id, $meta ) {
		// Only run when S3 integration is active (it shouldn't run otherwise, but check just in case),
		// and when the image does have sizes.
		if ( empty( $meta['sizes'] ) ) {
			return $paths;
		}
		$smush = WP_Smush::get_instance()->core()->mod->smush;
		foreach ( $meta['sizes'] as $size_key => $size_data ) {
			// Check if registered size is supposed to be Smushed or not.
			if ( 'full' !== $size_key && $smush->skip_image_size( $size_key ) ) {
				unset( $paths[ $size_key ] );
			}
		}

		return $paths;
	}

	/**
	 * S3 remove the local file without checking the exists,
	 * and they also log the warning into debug.log
	 * E.g When we convert PNG2JPG and delete the original files,
	 * and this will cause the missing files for S3.
	 * We only apply the filter on smush mode.
	 *
	 * @param  array $files_to_remove List file to remove on local.
	 * @return array
	 */
	public function remove_missing_files_to_avoid_error_log_from_s3( $files_to_remove ) {
		global $as3cf;
		if ( $as3cf && $as3cf->get_setting( 'remove-local-file' ) ) {
			foreach ( $files_to_remove as $size => $file_path ) {
				if ( ! file_exists( $file_path ) ) {
					unset( $files_to_remove[ $size ] );
				}
			}
		}
		return $files_to_remove;
	}

	/** Activating Private Media */

	/**
	 * Return true if private media is activated.
	 *
	 * @return boolean
	 */
	public function enable_private_media() {
		global $as3cf;
		return $as3cf && $as3cf->get_setting( 'enable-signed-urls' ) && ! empty( $as3cf->get_setting( 'signed-urls-object-prefix' ) );
	}

	/**
	 * Get object key.
	 *
	 * @see self::maybe_add_missing_files_to_the_list() for the detail.
	 *
	 * @since 3.9.6
	 *
	 * @param Media_Library_Item $s3_object An object item.
	 * @param string             $file_path File path.
	 * @param string             $size Image size.
	 *
	 * @return string
	 */
	private function get_object_key( Media_Library_Item $s3_object, $file_path, $size = 0 ) {
		if ( $this->enable_private_media() ) {
			$this->doing_files = array( $size => $file_path );
			// We use this trick to avoid S3 set the missing files as private files.
			add_filter( 'as3cf_attachment_file_paths', array( $this, 'maybe_add_missing_files_to_the_list' ) );
		}
		/**
		 * We use this method to support private mode too.
		 *
		 * @since 3.9.6
		 *
		 * @see Media_Library_Item()->key() (>=2.4)
		 */
		$key = $s3_object->key( wp_basename( $file_path ) );
		// Remove filter.
		if ( $this->doing_files ) {
			// Reset list files.
			$this->doing_files = null;
			remove_filter( 'as3cf_attachment_file_paths', array( $this, 'maybe_add_missing_files_to_the_list' ) );
		}

		return $key;
	}

	/**
	 * When enable private media,
	 * if the file is not in the list of file paths (AS3CF_Utils:get_attachment_file_paths()),
	 * S3 will set it's private size, but it's not managed fully,
	 * some other place, it will set is not private.
	 * So we use this trick to add the missing size keys.
	 *
	 * Note, we use size key smush-png2jpg-full for PNG2JPG file
	 * to remove the old PNG file after converting or converted JPG file after restoring in private folder.
	 *
	 * @since 3.9.6
	 *
	 * @param array $file_paths     List of the file paths.
	 *
	 * @return array List of file paths.
	 */
	public function maybe_add_missing_files_to_the_list( $file_paths ) {

		// Make sure exits the main file, not original file, and activating backup.
		if (
			isset( $file_paths['original'] )
			&& $this->doing_files
			&& $this->enable_private_media()
			&& WP_Smush::get_instance()->core()->mod->backup->is_active()
		) {
			foreach ( $this->doing_files as $size => $file ) {
				if ( 'smush-png2jpg-full' === $size ) {
					if ( isset( $file_paths['file'] ) && $file_paths['file'] === $file ) {
						unset( $file_paths['file'] );
					}
					$file_paths[''] = $file;
				} elseif ( is_string( $size ) ) {
					$file_paths[ $size ] = $file;
				} elseif ( ! in_array( $file, $file_paths, true ) ) {
					$file_paths[ 'smush_missing_key_' . basename( $file ) ] = $file;
				}
			}
		}

		return $file_paths;
	}

	/** End Private Media */

	/**************************************
	 *
	 * PRIVATE CLASSES
	 */

	/**
	 * Return true if S3 is activated.
	 *
	 * @since 3.9.6
	 *
	 * @return bool
	 */
	private function is_active() {
		static $is_active;
		if ( is_null( $is_active ) ) {
			$is_active = $this->enabled && $this->settings->get( $this->module ) && WP_Smush::is_pro();
		}
		return $is_active;
	}

	/**
	 * If enabling "Remove Files From Server",
	 * save all downloaded files to remove them later.
	 *
	 * @since 3.9.6
	 *
	 * @param string $file_path File path.
	 */
	private function add_file_to_remove( $file_path ) {
		global $as3cf;
		if ( $as3cf && $as3cf->get_setting( 'remove-local-file' ) ) {
			$this->files_to_remove[] = $file_path;
		}
	}

	/**
	 * Return unfiltered path.
	 *
	 * @since 3.9.6
	 *
	 * @param int    $attachment_id  Attachment ID.
	 * @param string $type           false|original|smush|backup|resize
	 *
	 * $type = original|backup => Try to get the original image file if it's available.
	 * $type = smush           => Get the file path ( if it exists ), or filtered file path if it doesn't exist.
	 * $type = original        => Only get the file path.
	 * $type = false           => Get the file path base on the setting "compress original".
	 *
	 * @see Helper::get_raw_attached_file()
	 *
	 * @return false|string
	 */
	private function get_raw_attached_file( $attachment_id, $type = false ) {
		/**
		 * S3 works with unfiltered path.
		 *
		 * @see AS3CF_Utils:get_attachment_file_paths() (>=1.2) and $as3cf->get_attachment_file_paths() (<1.2)
		 */
		// Temporary disable filters of get_attached_file.
		$this->temp_disable_s3_file_filter();
		// Get unfiltered file path.
		$file_path = Helper::get_raw_attached_file( $attachment_id, $type, true );
		// Revert S3 filters.
		$this->revert_s3_file_filter();

		return $file_path;
	}

	/**
	 * Get the main file filter class of S3.
	 * Before 2.6.0 it's $as3cf,
	 * From 2.6.0 it's \DeliciousBrains\WP_Offload_Media\Integrations\Media_Library_Integration
	 *
	 * @return false|object False or class instance.
	 */
	private function get_s3_filter_class() {
		static $s3_filter_obj;

		if ( isset( $s3_filter_obj ) ) {
			return $s3_filter_obj;
		}

		global $as3cf;

		if ( ! is_object( $as3cf ) ) {
			return false;
		}

		if ( method_exists( $as3cf, 'get_attached_file' ) ) {
			return $as3cf;
		}

		$s3_filter_obj = false;
		if ( method_exists( $as3cf, 'get_integration_manager' ) ) {
			if ( method_exists( $as3cf->get_integration_manager(), 'get_integration' ) ) {
				$media_library = $as3cf->get_integration_manager()->get_integration( 'mlib' );
				if ( method_exists( $media_library, 'get_attached_file' ) ) {
					$s3_filter_obj = $media_library;
				} else {
					Helper::logger()->integrations()->error( 'S3 - Media_Lib->get_attached_file does not exists.' );
				}
			}
		}

		return $s3_filter_obj;
	}

	/**
	 * Temporary disable S3 get_attached_file filter.
	 *
	 * @since 3.9.8
	 */
	private function temp_disable_s3_file_filter() {
		$s3_filter_obj = $this->get_s3_filter_class();
		if ( $s3_filter_obj ) {
			// Temporary disable filters URL from S3.
			remove_filter( 'get_attached_file', array( $s3_filter_obj, 'get_attached_file' ), 10, 2 );
			remove_filter( 'wp_get_original_image_path', array( $s3_filter_obj, 'get_attached_file' ), 10, 2 );
			return;
		}
		global $wp_filter;
		// Temporary disable all file filters.
		if ( isset( $wp_filter['get_attached_file'] ) ) {
			// Cache file filters.
			$this->list_file_filters['get_attached_file'] = $wp_filter['get_attached_file'];
			unset( $wp_filter['get_attached_file'] );

			if ( isset( $wp_filter['wp_get_original_image_path'] ) ) {
				$this->list_file_filters['get_attached_file'] = $wp_filter['wp_get_original_image_path'];
				unset( $wp_filter['wp_get_original_image_path'] );
			}
		}
	}

	/**
	 * Revert S3 get_attached_file filter.
	 *
	 * @since 3.9.8
	 */
	private function revert_s3_file_filter() {
		$s3_filter_obj = $this->get_s3_filter_class();
		if ( $s3_filter_obj ) {
			// Revert filters URL of S3.
			add_filter( 'get_attached_file', array( $s3_filter_obj, 'get_attached_file' ), 10, 2 );
			add_filter( 'wp_get_original_image_path', array( $s3_filter_obj, 'get_attached_file' ), 10, 2 );
			return;
		}
		// Maybe revert file filters.
		if ( $this->list_file_filters ) {
			global $wp_filter;
			$wp_filter['get_attached_file'] = $this->list_file_filters['get_attached_file'];//phpcs:ignore
			if ( isset( $this->list_file_filters['wp_get_original_image_path'] ) ) {
				$wp_filter['wp_get_original_image_path'] = $this->list_file_filters['wp_get_original_image_path'];//phpcs:ignore
			}
		}
	}

	/**
	 * Download a specified file to local server with respect to provided attachment id
	 * and/or Attachment path.
	 *
	 * @param string $file_path   Full file path.
	 * @param int    $attachment_id  Attachment ID.
	 *
	 * @since 3.9.6
	 * We use AS3CF_Plugin_Compatibility()->legacy_copy_back_to_local
	 * to download the file to avoid the new change and and support private mode too.
	 *
	 * @return bool|string  Returns file path or false
	 */
	private function download_file( $file_path, $attachment_id ) {
		if ( ! $this->is_active() || empty( $file_path ) || isset( $this->files_download_failed[ $file_path ] ) ) {
			return false;
		}

		/**
		 * Amazon_S3_And_CloudFront global.
		 *
		 * @var Amazon_S3_And_CloudFront $as3cf
		 */
		global $as3cf;

		// Check if the file exists on the server.
		if ( file_exists( $file_path ) ) {
			return $file_path;
		}

		if ( ! isset( $as3cf->plugin_compat ) || ! method_exists( $as3cf->plugin_compat, 'legacy_copy_back_to_local' ) ) {
			Helper::logger()->integrations()->error( 'S3 - Method $as3cf->plugin_compat->legacy_copy_back_to_local() does not exists.' );
			return false;
		}

		$as3cf_item = $this->is_attachment_served_by_provider( $as3cf, $attachment_id );
		if ( ! $as3cf_item ) {
			return false;
		}

		$file = false;

		// Enable "copy file back to local", priority is 9999 > Smush mode 9998.
		add_filter( 'as3cf_get_attached_file_copy_back_to_local', '__return_true', 9999 );
		/**
		 * Download file back to local.
		 *
		 * @since 3.9.6
		 *
		 * We use this way to download the file to avoid the new change, and support private mode too.
		 *
		 * @see AS3CF_Plugin_Compatibility()->legacy_copy_back_to_local (>=1.x)
		 * @see Media_Library_Item()->key() (>= 2.4)
		 *
		 * We set the default URL as 0 just for debugging purposes.
		 */
		$file = $as3cf->plugin_compat->legacy_copy_back_to_local( 0, $file_path, $attachment_id, $as3cf_item );
		/**
		 * If there is a not found image, and if we don't check it exists before downloading it,
		 * then S3 will save the current error log as an error image the same as the provided path.
		 * So we need to delete it to avoid the error.
		 *
		 * @since 3.9.6
		 */
		if ( ! $file ) {
			// Cache the result to avoid downloading it again.
			$this->files_download_failed[ $file_path ] = $file;
			if ( file_exists( $file_path ) ) {
				unlink( $file_path );
			}
		}

		// Restore "copy file back to local" status.
		remove_filter( 'as3cf_get_attached_file_copy_back_to_local', '__return_true', 9999 );

		// If we don't have the file, Try it the basic way.
		if ( ! $file ) {
			$s3_url = $this->is_image_on_s3( $attachment_id );

			// If we couldn't get the image URL, return false.
			if ( is_wp_error( $s3_url ) || empty( $s3_url ) ) {
				return false;
			}

			// Make sure function download_url available.
			if ( ! function_exists( 'download_url' ) ) {
				require_once ABSPATH . 'wp-admin/includes/file.php';
			}

			// Get the File path using basename for given attachment path.
			$s3_url = str_replace( wp_basename( $s3_url ), wp_basename( $file_path ), $s3_url );

			// Download the file.
			$temp_file = download_url( $s3_url );
			$renamed   = false;
			if ( ! is_wp_error( $temp_file ) ) {
				$renamed = @copy( $temp_file, $file_path );
				unlink( $temp_file );
			} else {
				Helper::logger()->integrations()->error( 'S3 - Cannot download file [%s] due to error: %s', Helper::clean_file_path( $file_path ), $temp_file->get_error_message() );
			}

			// If we were able to successfully rename the file, return file path.
			if ( $renamed ) {
				// The file was downloaded, so remove it from the cached.
				if ( isset( $this->files_download_failed[ $file_path ] ) ) {
					unset( $this->files_download_failed[ $file_path ] );
				}
				$file = $file_path;
			}
		}

		// Save all downloaded files to remove them later.
		$this->add_file_to_remove( $file_path );

		return $file;
	}

	/**
	 * Check if file exists for the given path
	 *
	 * @param string $attachment_id  Attachment ID.
	 * @param string $file_path      File path.
	 *
	 * @return bool
	 */
	private function does_image_exists( $attachment_id, $file_path ) {
		/**
		 * Amazon_S3_And_CloudFront global.
		 *
		 * @var Amazon_S3_And_CloudFront $as3cf
		 */
		global $as3cf;

		if ( empty( $attachment_id ) || empty( $file_path ) ) {
			return false;
		}

		// Get s3 object for the file.
		if ( ! $s3_object = $this->is_attachment_served_by_provider( $as3cf, $attachment_id ) ) {// phpcs:ignore
			return false;
		}

		// Get file key.
		$is_object = is_object( $s3_object );
		if ( $is_object && $s3_object instanceof Media_Library_Item && method_exists( $s3_object, 'key' ) ) {
			$key = $this->get_object_key( $s3_object, $file_path );
		} else {
			// Try with the old version.
			if ( $is_object ) {
				$key = $s3_object->path();
			} else {
				$key = $s3_object['key'];
			}

			$size_prefix      = dirname( $key );
			$size_file_prefix = ( '.' === $size_prefix ) ? '' : $size_prefix . '/';

			// Get the File path using basename for given attachment path.
			$key = path_join( $size_file_prefix, wp_basename( $file_path ) );
		}

		$bucket   = $as3cf->get_setting( 'bucket' );
		$s3client = $this->get_provider_client();
		if ( ! $s3client ) {
			Helper::logger()->integrations()->error( 'S3 - Provider client does not exists.' );
			return false;
		}

		// If we still have the older version of S3 Offload, use old method.
		if ( method_exists( $s3client, 'does_object_exist' ) ) {
			$file_exists = $s3client->does_object_exist( $bucket, $key );
		} elseif ( method_exists( $s3client, 'doesObjectExist' ) ) {
			$file_exists = $s3client->doesObjectExist( $bucket, $key );
		} else {
			Helper::logger()->integrations()->error( 'S3 - Method AWS_Provider->does_object_exist does not exist.' );
			$file_exists = false;
		}

		return $file_exists;
	}

	/**
	 * Check if S3 support is required for Smush.
	 *
	 * @return bool
	 */
	private function s3_support_required() {
		/**
		 * Amazon_S3_And_CloudFront global.
		 *
		 * @var Amazon_S3_And_CloudFront $as3cf
		 */
		global $as3cf;

		// Check if S3 offload plugin is active and delete file from server option is enabled.
		if ( ! is_object( $as3cf ) || ! method_exists( $as3cf, 'get_setting' ) || ! $as3cf->get_setting( 'remove-local-file' ) ) {
			return false;
		}

		// If not Pro user or S3 support is disabled.
		return ( ! WP_Smush::is_pro() || ! $this->settings->get( $this->module ) );
	}

	/**
	 * Wrapper method.
	 *
	 * Check if the attachment is server by S3.
	 *
	 * @since 3.0
	 *
	 * @param Amazon_S3_And_CloudFront $as3cf          Amazon_S3_And_CloudFront global.
	 * @param int                      $attachment_id  Attachment ID.
	 *
	 * @return bool|array|Media_Library_Item Version < 2.3 Returns an array, >= 2.3 Media_Library_Item
	 */
	private function is_attachment_served_by_provider( $as3cf, $attachment_id ) {
		if ( ! $as3cf ) {
			return false;
		}
		// Version >= 2.0.0.
		if ( method_exists( $as3cf, 'is_attachment_served_by_provider' ) ) {
			return $as3cf->is_attachment_served_by_provider( $attachment_id, true );
		} elseif ( method_exists( $as3cf, 'is_attachment_served_by_s3' ) ) {
			// Version < 2.0.0.
			return $as3cf->is_attachment_served_by_s3( $attachment_id, true );
		} else {
			Helper::logger()->integrations()->error( 'S3 - Method $as3cf->is_attachment_served_by_provider() does not exists.' );
		}

		return false;
	}

	/**
	 * Wrapper method.
	 *
	 * Copy file to server.
	 *
	 * @since 3.0
	 *
	 * @param Amazon_S3_And_CloudFront $as3cf         Amazon_S3_And_CloudFront global.
	 * @param array|object             $s3_object     Data array.
	 * @param string                   $uf_file_path  File path.
	 *
	 * @return bool|string
	 */
	private function copy_provider_file_to_server( $as3cf, $s3_object, $uf_file_path ) {
		if ( ! is_object( $as3cf->plugin_compat ) ) {
			return false;
		}

		if ( method_exists( $as3cf->plugin_compat, 'copy_provider_file_to_server' ) ) {
			return $as3cf->plugin_compat->copy_provider_file_to_server( $s3_object, $uf_file_path );
		} elseif ( method_exists( $as3cf->plugin_compat, 'copy_s3_file_to_server' ) ) {
			return $as3cf->plugin_compat->copy_s3_file_to_server( $s3_object, $uf_file_path );
		} else {
			Helper::logger()->integrations()->error( 'S3 - Method $as3cf->plugin_compat->copy_provider_file_to_server() does not exists.' );
		}

		return false;
	}

	/**
	 * Wrapper method.
	 *
	 * Get provider client.
	 *
	 * @since 3.0
	 *
	 * @return \Provider|\Null_Provider|bool
	 * @throws \Exception Exception.
	 */
	private function get_provider_client() {
		global $as3cf;
		// Get bucket details.
		$region = $as3cf->get_setting( 'region' );
		if ( is_wp_error( $region ) ) {
			Helper::logger()->integrations()->error( 'S3 - Cannot retrieve the region: %s', $region->get_error_message() );
			$region = '';
		}
		if ( method_exists( $as3cf, 'get_provider_client' ) ) {
			return $as3cf->get_provider_client( $region );
		} elseif ( method_exists( $as3cf, 'get_s3client' ) ) {
			return $as3cf->get_s3client( $region );
		} else {
			Helper::logger()->integrations()->error( 'S3 - Method $as3cf->get_provider_client() does not exists.' );
		}

		return false;
	}

	/**
	 * Update the original source path after converting PNG to JPG.
	 *
	 * @since 3.9.6
	 *
	 * @param int    $attachment_id Attachment ID.
	 * @param string $old_filepath  Old PNG file path.
	 * @param string $new_filename  New file name in JPG.
	 * @param string $size          Image size name.
	 */
	public function update_original_source_path_after_png2jpg( $attachment_id, $old_filepath, $new_filename, $size ) {
		if ( 'full' === $size ) {
			$this->update_original_source_path( $attachment_id, $new_filename, $old_filepath );
		}
	}

	/**
	 * Update the original source path after restoring JPG to PNG.
	 *
	 * @since 3.9.6
	 *
	 * @param int    $attachment_id Attachment ID.
	 * @param string $old_filepath  Old JPG file path.
	 * @param string $new_filepath  Restored file path - New PNG file path.
	 */
	public function update_original_source_path_after_restore_png( $attachment_id, $old_filepath, $new_filepath ) {
		/**
		 * After restore we also need to update the source path,
		 * to make sure the JPG file does not exists and avoid unique file name issue.
		 * $is_restoring = true.
		 */
		$this->update_original_source_path( $attachment_id, $new_filepath, $old_filepath, true );
	}

	/**
	 * Update the original source path after changing the file format (PNG<->JPG).
	 *
	 * @since 3.9.6
	 *
	 * @param int    $attachment_id Attachment ID.
	 * @param string $new_file      New file path/name.
	 * @param string $old_filepath  Old file path (origin PNG| converted JPG).
	 * @param bool   $is_restoring  Is restoring or converting PNG2JPG.
	 */
	private function update_original_source_path( $attachment_id, $new_file, $old_filepath, $is_restoring = false ) {
		global $as3cf;
		$as3cf_item = $this->is_attachment_served_by_provider( $as3cf, $attachment_id );
		if ( ! ( $as3cf_item && is_object( $as3cf_item ) && $as3cf_item instanceof Media_Library_Item && method_exists( $as3cf_item, 'key' ) && method_exists( $as3cf_item, 'is_private' ) ) ) {
			Helper::logger()->integrations()->error( 'S3 - Media_Library_Item->is_private does not exist.' );
			return false;
		}
		// If user enabling remove file on local, we will remove all our old PNG/JPG files from list of file paths to avoid error log.
		if ( $as3cf && $as3cf->get_setting( 'remove-local-file' ) ) {
			// We don't remove the filter because it might be called later.
			add_filter( 'as3cf_upload_attachment_local_files_to_remove', array( $this, 'remove_missing_files_to_avoid_error_log_from_s3' ), 99 );
		}

		$new_filename = basename( $new_file );
		$as3cf_item   = new Media_Library_Item(
			$as3cf_item->provider(),
			$as3cf_item->region(),
			$as3cf_item->bucket(),
			path_join( dirname( $as3cf_item->path() ), $new_filename ),
			$as3cf_item->is_private(),
			$as3cf_item->source_id(),
			path_join( dirname( $as3cf_item->source_path() ), $new_filename ),
			$new_filename,
			$as3cf_item->extra_info(),
			$as3cf_item->id()
		);

		$as3cf_item->save();

		// If enable private media, try to delete old PNG file of PNG2JPG.
		if ( $this->enable_private_media() ) {
			$backup = WP_Smush::get_instance()->core()->mod->backup;
			if ( $as3cf_item->is_private() ) {
				if ( $is_restoring ) {
					// Remove the original PNG file as a backup file in public folder.
					if ( $as3cf_item->key() !== $as3cf_item->path() && $backup->is_active() ) {
						$object_key = path_join( dirname( $as3cf_item->path() ), basename( $new_file ) );
					}
				} else {
					// Remove the original PNG file in private folder.
					$object_key = path_join( dirname( $as3cf_item->key() ), basename( $old_filepath ) );
				}
			} elseif ( $backup->is_active() && ( method_exists( $as3cf_item, 'is_private_size' ) && $as3cf_item->is_private_size( 'smush-full' ) || $as3cf_item->is_private( 'smush-full' ) ) ) {
				if ( method_exists( $as3cf_item, 'private_prefix' ) && method_exists( $as3cf_item, 'normalized_path_dir' ) ) {
					/**
					 * Remove old PNG file when user enable private media for backup size,
					 * and doesn't activate the image yet.
					 *
					 * E.g:
					 * function smush_as3cf_upload_acl_sizes( $acl, $size, $post_id, $metadata ) {
					 *  // Enable private for smush backup size.
					 *  if ( 'smush-full' === $size ) {
					 *      return 'private';
					 *  }

					*  return $acl;
					* }
					* add_filter( 'as3cf_upload_acl_sizes', 'smush_as3cf_upload_acl_sizes', 10, 4 );
					*/

					if ( $is_restoring ) {
						// Remove the original PNG file as a backup file in private folder.
						$object_key = $as3cf_item->private_prefix() . $as3cf_item->normalized_path_dir() . basename( $new_file );
					} else {
						// Remove the original PNG file in public folder after converting to JPG.
						$object_key = $as3cf_item->key( basename( $old_filepath ) );
					}
				} else {
					Helper::logger()->integrations()->error( 'S3 - Method $as3cf->private_prefix() or $as3cf->normalized_path_dir() does not exists.' );
				}
			}

			// Delete old PNG file.
			if ( isset( $object_key ) ) {
				$objects_to_remove[] = array(
					'Key' => $object_key,
				);
				$this->delete_objects( $objects_to_remove );
			}
		}
	}

}
