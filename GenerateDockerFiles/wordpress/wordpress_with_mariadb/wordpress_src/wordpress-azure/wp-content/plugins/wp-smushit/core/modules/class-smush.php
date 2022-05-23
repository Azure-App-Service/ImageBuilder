<?php
/**
 * Smush core class: Smush class
 *
 * @package Smush\Core\Modules
 */

namespace Smush\Core\Modules;

use Smush\Core\Core;
use Smush\Core\Helper;
use WP_Error;
use WP_Smush;

if ( ! defined( 'WPINC' ) ) {
	die;
}

/**
 * Class Smush
 */
class Smush extends Abstract_Module {

	/**
	 * Meta key to save smush result to db.
	 *
	 * @var string $smushed_meta_key
	 */
	public static $smushed_meta_key = 'wp-smpro-smush-data';

	/**
	 * Images dimensions array.
	 *
	 * @var array $image_sizes
	 */
	public $image_sizes = array();

	/**
	 * Stores the headers returned by the latest API call.
	 *
	 * @var array $api_headers
	 */
	protected $api_headers = array();

	/**
	 * Prevent third party try to run another smush while it's running.
	 *
	 * @access private
	 *
	 * @var bool
	 */
	private $prevent_infinite_loop;

	/**
	 * WP_Smush constructor.
	 */
	public function init() {
		// Update the Super Smush count, after the Smush'ing.
		add_action( 'wp_smush_image_optimised', array( $this, 'update_lists' ), '', 2 );

		// Smush image (Auto Smush) when `wp_generate_attachment_metadata` filter is fired.
		add_filter( 'wp_generate_attachment_metadata', array( $this, 'smush_image' ), 15, 2 );

		// Delete backup files.
		add_action( 'delete_attachment', array( $this, 'delete_images' ), 12 );

		// Handle the Async optimisation.
		add_action( 'wp_async_wp_generate_attachment_metadata', array( $this, 'wp_smush_handle_async' ) );
		add_action( 'wp_async_wp_save_image_editor_file', array( $this, 'wp_smush_handle_editor_async' ), '', 2 );

		// Make sure we treat scaled images as additional size.
		add_filter( 'wp_smush_add_scaled_images_to_meta', array( $this, 'add_scaled_to_meta' ), 10, 2 );

		// Fix SSL CA certificates issue.
		add_action( 'wp_smush_before_smush_file', array( $this, 'fix_ssl_ca_certificate_error' ) );
	}

	/**
	 * Check whether to show warning or not for Pro users, if they don't have a valid install
	 *
	 * @return bool
	 */
	public function show_warning() {
		// If it's a free setup, Go back right away!
		if ( ! WP_Smush::is_pro() ) {
			return false;
		}

		// Return. If we don't have any headers.
		if ( ! isset( $this->api_headers ) ) {
			return false;
		}

		// Show warning, if function says it's premium and api says not premium.
		if ( isset( $this->api_headers['is_premium'] ) && ! (int) $this->api_headers['is_premium'] ) {
			return true;
		}

		return false;
	}

	/**
	 * Add/Remove image id from Super Smushed images count.
	 *
	 * @param int    $id       Image id.
	 * @param string $op_type  Add/remove, whether to add the image id or remove it from the list.
	 * @param string $key      Options key.
	 *
	 * @return bool Whether the Super Smushed option was update or not
	 */
	public function update_super_smush_count( $id, $op_type = 'add', $key = 'wp-smush-super_smushed' ) {
		// Get the existing count.
		$super_smushed = get_option( $key, false );

		// Initialize if it doesn't exists.
		if ( ! $super_smushed || empty( $super_smushed['ids'] ) ) {
			$super_smushed = array(
				'ids' => array(),
			);
		}

		// Insert the id, if not in there already.
		if ( 'add' === $op_type && ! in_array( $id, $super_smushed['ids'] ) ) {
			$super_smushed['ids'][] = $id;
		} elseif ( 'remove' === $op_type && false !== ( $k = array_search( $id, $super_smushed['ids'] ) ) ) {
			// Else remove the id from the list.
			unset( $super_smushed['ids'][ $k ] );

			// Reset all the indexes.
			$super_smushed['ids'] = array_values( $super_smushed['ids'] );
		}

		// Add the timestamp.
		$super_smushed['timestamp'] = current_time( 'timestamp' );

		update_option( $key, $super_smushed, false );

		// Update to database.
		return true;
	}

	/**
	 * Checks if the image compression is lossy, stores the image id in options table
	 *
	 * @param int    $id     Image Id.
	 * @param array  $stats  Compression Stats.
	 * @param string $key    Meta Key for storing the Super Smushed ids (Optional for Media Library).
	 *                       Need To be specified for NextGen.
	 *
	 * @return bool
	 */
	public function update_lists( $id, $stats, $key = '' ) {
		// If Stats are empty or the image id is not provided, return.
		if ( empty( $stats ) || empty( $id ) || empty( $stats['stats'] ) ) {
			return false;
		}

		// Update Super Smush count.
		if ( isset( $stats['stats']['lossy'] ) && 1 == $stats['stats']['lossy'] ) {
			if ( empty( $key ) ) {
				update_post_meta( $id, 'wp-smush-lossy', 1 );
			} else {
				$this->update_super_smush_count( $id, 'add', $key );
			}
		}

		// Check and update re-smush list for media gallery.
		if ( ! empty( $this->resmush_ids ) && in_array( $id, $this->resmush_ids ) ) {
			$this->update_resmush_list( $id );
		}
	}

	/**
	 * Remove the given attachment id from resmush list and updates it to db
	 *
	 * @param string $attachment_id  Attachment ID.
	 * @param string $mkey           Option key.
	 */
	public function update_resmush_list( $attachment_id, $mkey = 'wp-smush-resmush-list' ) {
		$resmush_list = get_option( $mkey );

		// If there are any items in the resmush list, Unset the Key.
		if ( ! empty( $resmush_list ) && count( $resmush_list ) > 0 ) {
			$key = array_search( $attachment_id, $resmush_list );
			if ( $resmush_list ) {
				unset( $resmush_list[ $key ] );
			}
			$resmush_list = array_values( $resmush_list );
		}

		// If Resmush List is empty.
		if ( empty( $resmush_list ) || 0 === count( $resmush_list ) ) {
			// Delete resmush list.
			delete_option( $mkey );
		} else {
			update_option( $mkey, $resmush_list, false );
		}
	}

	/**
	 * Remove the Update info.
	 *
	 * @param bool $remove_notice  Remove notice.
	 */
	public function dismiss_update_info( $remove_notice = false ) {
		// From URL arg.
		if ( isset( $_GET['dismiss_smush_update_info'] ) && 1 == $_GET['dismiss_smush_update_info'] ) {
			$remove_notice = true;
		}

		// From Ajax.
		if ( ! empty( $_REQUEST['action'] ) && 'dismiss_update_info' === $_REQUEST['action'] ) {
			$remove_notice = true;
		}

		// Update Db.
		if ( $remove_notice ) {
			update_site_option( 'wp-smush-hide_update_info', 1 );
		}
	}

	/**
	 * Check whether to skip a specific image size or not.
	 *
	 * @param string $size  Registered image size.
	 *
	 * @return bool Skip the image size or not.
	 */
	public function skip_image_size( $size ) {
		// No image size specified, Don't skip.
		if ( empty( $size ) ) {
			return false;
		}

		$image_sizes = $this->settings->get_setting( 'wp-smush-image_sizes' );

		// If image sizes aren't set, don't skip any of the image size.
		if ( false === $image_sizes ) {
			return false;
		}

		// Check if the size is in the smush list.
		return is_array( $image_sizes ) && ! in_array( $size, $image_sizes, true );
	}

	/**
	 * Process an image with Smush.
	 *
	 * @since 3.8.0 Added new param $convert_to_webp.
	 *
	 * @param string $file_path        Absolute path to the image.
	 * @param bool   $convert_to_webp  Convert the image to webp.
	 *
	 * @return array|bool|WP_Error
	 */
	public function do_smushit( $file_path = '', $convert_to_webp = false ) {
		$errors   = new WP_Error();
		$dir_name = trailingslashit( dirname( $file_path ) );

		// Check if file exists and the directory is writable.
		if ( empty( $file_path ) ) {
			$errors->add( 'empty_path', __( 'File path is empty', 'wp-smushit' ) );
		} elseif ( ! file_exists( $file_path ) || ! is_file( $file_path ) ) {
			// Check that the file exists.
			/* translators: %s: file path */
			$errors->add( 'file_not_found', sprintf( __( 'Could not find %s', 'wp-smushit' ), $file_path ) );
		} elseif ( ! is_writable( $dir_name ) ) {
			// Check that the file is writable.
			/* translators: %s: directory name */
			$errors->add( 'not_writable', sprintf( __( '%s is not writable', 'wp-smushit' ), $dir_name ) );
		}

		$file_size = file_exists( $file_path ) ? filesize( $file_path ) : '';

		// Check if premium user.
		$max_size = WP_Smush::is_pro() ? WP_SMUSH_PREMIUM_MAX_BYTES : WP_SMUSH_MAX_BYTES;

		// Check if file exists.
		if ( 0 === (int) $file_size ) {
			/* translators: %1$s: image size, %2$s: image name */
			$errors->add( 'image_not_found', sprintf( __( 'Skipped (%1$s), image not found', 'wp-smushit' ), size_format( $file_size, 1 ) ) );
		} elseif ( $file_size > $max_size ) {
			// Check size limit.
			/* translators: %1$s: image size, %2$s: image name */
			$errors->add( 'size_limit', sprintf( __( 'Skipped (%1$s), size limit exceeded', 'wp-smushit' ), size_format( $file_size, 1 ) ) );
		}

		if ( count( $errors->get_error_messages() ) ) {
			Helper::logger()->error(
				array(
					sprintf( 'Skipped file [%s] due to error:', Helper::clean_file_path( $file_path ) ),
					$errors->get_error_messages(),
				)
			);
			return $errors;
		}

		// Save original file permissions.
		clearstatcache();
		$perms = fileperms( $file_path ) & 0777;

		// Optimize image, and fetch the response.
		$response = $this->_post( $file_path, $convert_to_webp );

		if ( ! $response['success'] ) {
			$errors->add( 'false_response', $response['message'] );
		} elseif ( empty( $response['data'] ) ) {
			// If there is no data.
			$errors->add( 'no_data', __( 'Unknown API error', 'wp-smushit' ) );
		}

		if ( count( $errors->get_error_messages() ) ) {
			Helper::logger()->error(
				array(
					sprintf( $convert_to_webp ? 'Cannot convert to webp for image [%s].' : 'Cannot smush image [%s].', Helper::clean_file_path( $file_path ) ),
					$errors->get_error_messages(),
				)
			);
			return $errors;
		}

		// If there are no savings, or image returned is bigger (size).
		if ( ( ! empty( $response['data']->bytes_saved ) && (int) $response['data']->bytes_saved ) <= 0 || empty( $response['data']->image ) ) {
			$bytes_saved = ! empty( $response['data']->bytes_saved ) ? $response['data']->bytes_saved : 0;
			Helper::logger()->notice( sprintf( 'The smushed image is larger than the original image [%s] (bytes saved %d), keep original image.', Helper::clean_file_path( $file_path ), $bytes_saved ) );
			return $response;
		}

		if ( $convert_to_webp ) {
			$file_path = WP_Smush::get_instance()->core()->mod->webp->get_webp_file_path( $file_path, true );
			file_put_contents( $file_path, $response['data']->image );
		} else {
			$temp_file = $file_path . '.tmp';

			// Add the file as tmp.
			file_put_contents( $temp_file, $response['data']->image );

			// Replace the file.
			$success = rename( $temp_file, $file_path );

			// If temp file still exists, unlink it.
			if ( file_exists( $temp_file ) ) {
				unlink( $temp_file );
			}

			// If file renaming failed.
			if ( ! $success ) {
				copy( $temp_file, $file_path );
				unlink( $temp_file );
			}
		}

		// Some servers are having issue with file permission, this should fix it.
		if ( empty( $perms ) || ! $perms ) {
			// Source: WordPress Core.
			$stat  = stat( dirname( $file_path ) );
			$perms = $stat['mode'] & 0000666; // Same permissions as parent folder, strip off the executable bits.
		}

		chmod( $file_path, $perms );

		return $response;
	}

	/**
	 * Posts an image to Smush.
	 *
	 * @since 3.8.0 Added new param $convert_to_webp.
	 *
	 * @param string $file_path        Path of file to send to Smush.
	 * @param bool   $convert_to_webp  Convert the image to webp.
	 *
	 * @return bool|array array containing success status, and stats
	 */
	private function _post( $file_path, $convert_to_webp = false ) {
		$headers = array(
			'accept'       => 'application/json',   // The API returns JSON.
			'content-type' => 'application/binary', // Set content type to binary.
			'lossy'        => WP_Smush::is_pro() && $this->settings->get( 'lossy' ) ? 'true' : 'false',
			'exif'         => $this->settings->get( 'strip_exif' ) ? 'false' : 'true',
		);

		if ( $convert_to_webp ) {
			$headers['webp'] = 'true';
		}

		// Check if premium member, add API key.
		$api_key = Helper::get_wpmudev_apikey();
		if ( ! empty( $api_key ) && WP_Smush::is_pro() ) {
			$headers['apikey'] = $api_key;
		}

		$api_url = defined( 'WP_SMUSH_API_HTTP' ) ? WP_SMUSH_API_HTTP : WP_SMUSH_API;
		$args    = array(
			'headers'    => $headers,
			'body'       => file_get_contents( $file_path ),
			'timeout'    => WP_SMUSH_TIMEOUT,
			'user-agent' => WP_SMUSH_UA,
		);

		// Temporary increase the limit.
		wp_raise_memory_limit( 'image' );
		$result = wp_remote_post( $api_url, $args );
		unset( $args ); // Free memory.

		if ( is_wp_error( $result ) ) {
			$er_msg = $result->get_error_message();

			// Hostgator issue.
			if ( ! empty( $er_msg ) && strpos( $er_msg, 'SSL CA cert' ) !== false ) {
				// Update DB for using http protocol.
				$this->settings->set_setting( 'wp-smush-use_http', 1 );
			}

			// Check for timeout error and suggest to filter timeout.
			if ( strpos( $er_msg, 'timed out' ) ) {
				$data['message'] = esc_html__( "Skipped due to a timeout error. You can increase the request timeout to make sure Smush has enough time to process larger files. define('WP_SMUSH_TIMEOUT', 150);", 'wp-smushit' );
			} else {
				// Handle error.
				/* translators: %s error message */
				$data['message'] = sprintf( __( 'Error posting to API: %s', 'wp-smushit' ), $result->get_error_message() );
			}

			$data['success'] = false;
			unset( $result ); // Free memory.
			return $data;
		} elseif ( 200 !== wp_remote_retrieve_response_code( $result ) ) {
			// Handle error.
			/* translators: %1$s: response code, %2$s error message */
			$data['message'] = sprintf( __( 'Error posting to API: %1$s %2$s', 'wp-smushit' ), wp_remote_retrieve_response_code( $result ), wp_remote_retrieve_response_message( $result ) );
			$data['success'] = false;
			unset( $result ); // Free memory.
			return $data;
		}

		// If there is a response and image was successfully optimised.
		$response = json_decode( $result['body'] );
		if ( $response && true === $response->success ) {
			// If there is any savings.
			if ( $response->data->bytes_saved > 0 ) {
				// base64_decode is necessary to send binary img over JSON, no security problems here!
				$image     = base64_decode( $response->data->image );
				$image_md5 = md5( $response->data->image );
				if ( $response->data->image_md5 !== $image_md5 ) {
					// Handle error.
					$data['message'] = __( 'Smush data corrupted, try again.', 'wp-smushit' );
					$data['success'] = false;
				} else {
					$data['success']     = true;
					$data['data']        = $response->data;
					$data['data']->image = $image;
				}
				unset( $image );// Free memory.
			} else {
				// Just return the data.
				$data['success'] = true;
				$data['data']    = $response->data;
			}

			// Check for API message and store in db.
			if ( isset( $response->data->api_message ) && ! empty( $response->data->api_message ) ) {
				$this->add_api_message( $response->data->api_message );
			}

			// If is_premium is set in response, send it over to check for member validity.
			if ( ! empty( $response->data ) && isset( $response->data->is_premium ) ) {
				$this->api_headers['is_premium'] = $response->data->is_premium;
			}
		} else {
			// Server side error, get message from response.
			$data['message'] = ! empty( $response->data ) ? $response->data : __( "Image couldn't be smushed", 'wp-smushit' );
			$data['success'] = false;
		}

		return $data;
	}

	/**
	 * Replace the old API message with the latest one if it doesn't exists already
	 *
	 * @param array $api_message  API message.
	 */
	private function add_api_message( $api_message = array() ) {
		if ( empty( $api_message ) || ! count( $api_message ) || empty( $api_message['timestamp'] ) || empty( $api_message['message'] ) ) {
			return;
		}
		$o_api_message = get_site_option( 'wp-smush-api_message', array() );
		if ( array_key_exists( $api_message['timestamp'], $o_api_message ) ) {
			return;
		}
		$api_message['status'] = 'show';

		$message                              = array();
		$message[ $api_message['timestamp'] ] = array(
			'message' => sanitize_text_field( $api_message['message'] ),
			'type'    => sanitize_text_field( $api_message['type'] ),
			'status'  => 'show',
		);
		update_site_option( 'wp-smush-api_message', $message );
	}

	/**
	 * Fills $placeholder array with values from $data array
	 *
	 * @param array $placeholders  Placeholders array.
	 * @param array $data          Data to fill with.
	 *
	 * @return array
	 */
	public function array_fill_placeholders( array $placeholders, array $data ) {
		$placeholders['percent']     = $data['compression'];
		$placeholders['bytes']       = $data['bytes_saved'];
		$placeholders['size_before'] = $data['before_size'];
		$placeholders['size_after']  = $data['after_size'];
		$placeholders['time']        = $data['time'];

		return $placeholders;
	}

	/**
	 * Returns signature for single size of the smush api message to be saved to db;
	 *
	 * @return array
	 */
	public function get_size_signature() {
		return array(
			'percent'     => 0,
			'bytes'       => 0,
			'size_before' => 0,
			'size_after'  => 0,
			'time'        => 0,
		);
	}

	/**
	 * Optimises the image sizes
	 *
	 * Note: Function name is a bit confusing, it is for optimisation, and calls the resizing function as well
	 *
	 * Read the image paths from an attachment's metadata and process each image
	 * with wp_smushit().
	 *
	 * @param int   $attachment_id  Image ID.
	 * @param array $meta           Image metadata.
	 *
	 * @return WP_Error|array
	 */
	public function resize_from_meta_data( $attachment_id, $meta ) {
		// Check if it's real a image, and is supported.
		if ( ! Helper::is_smushable( $attachment_id ) ) {
			return $meta;
		}

		// Maybe add scaled file to the meta sizes.
		$meta = apply_filters( 'wp_smush_add_scaled_images_to_meta', $meta, $attachment_id );

		// Flag to check, if uploaded size image should be smushed or not.
		$smush_uploaded = true === $this->settings->get( 'original' );

		$stats = array(
			'stats' => array_merge(
				$this->get_size_signature(),
				array(
					'api_version' => - 1,
					'lossy'       => - 1,
					'keep_exif'   => false,
				)
			),
			'sizes' => array(),
		);

		// File path and URL for original image.
		$file_path = Helper::get_attached_file( $attachment_id );// S3+.

		// If images has other registered size, smush them first.
		if ( ! empty( $meta['sizes'] ) && ! has_filter( 'wp_image_editors', 'photon_subsizes_override_image_editors' ) ) {
			$optimized_thumbs = array();
			foreach ( $meta['sizes'] as $size_key => $size_data ) {
				// Check if registered size is supposed to be Smushed or not.
				if ( 'full' !== $size_key ) {
					if ( $this->skip_image_size( $size_key ) || isset( $optimized_thumbs[ $size_data['file'] ] ) ) {
						// If a thumbnail file is optimized we don't need to optimize it again.
						continue;
					}
					/**
					 * Save optimized thumbnail file.
					 * We save all cases included failure case which user can re-check images later.
					 */
					$optimized_thumbs[ $size_data['file'] ] = $size_key;
				}

				// We take the original image. The 'sizes' will all match the same URL and
				// path. So just get the dirname and replace the filename.
				$file_path_size = path_join( dirname( $file_path ), $size_data['file'] );

				$ext = Helper::get_mime_type( $file_path_size );
				if ( $ext && false === array_search( $ext, Core::$mime_types, true ) ) {
					continue;
				}

				/**
				 * Allows to skip an image from optimization.
				 *
				 * @param bool   $compress       Optimize image or not.
				 * @param string $size_key       Size of image being smushed.
				 * @param string $file_path_size Full thumbnail path of current size.
				 * @param int    $attachment_id  Attachment ID.
				 *
				 * @since 3.9.6 Add two parameters for the filter.
				 */
				if ( ! apply_filters( 'wp_smush_media_image', true, $size_key, $file_path_size, $attachment_id ) ) {
					continue;
				}

				/**
				 * Check if the file exists on the server,
				 * if not, might try to download it from the cloud (s3).
				 *
				 * @since 3.9.6
				 */
				if ( ! Helper::exists_or_downloaded( $file_path_size, $attachment_id ) ) {
					continue;
				}

				// Store details for each size key.
				$response = $this->do_smushit( $file_path_size );

				if ( is_wp_error( $response ) ) {
					// Logged the error inside do_smushit.
					return $response;
				}

				// If there are no stats or resulting image is larger than original.
				if ( empty( $response['data'] ) || $response['data']->after_size > $response['data']->before_size ) {
					continue;
				}

				// All clear, store the stat.
				$stats['sizes'][ $size_key ] = (object) $this->array_fill_placeholders( $this->get_size_signature(), (array) $response['data'] );
			}
		} elseif ( ! has_filter( 'wp_image_editors', 'photon_subsizes_override_image_editors' ) ) {
			$smush_uploaded = true;
		}

		/**
		 * Allows to skip an image from optimization.
		 *
		 * @param bool   $compress  Optimize image or not.
		 * @param string $size_key  Size of image being smushed.
		 */
		$smush_full_image = apply_filters( 'wp_smush_media_image', true, 'full', $file_path, $attachment_id );

		// If original size is supposed to be smushed.
		if ( $smush_uploaded && $smush_full_image ) {
			$response = $this->do_smushit( $file_path );

			if ( is_wp_error( $response ) ) {
				// Logged the error inside do_smushit.
				return $response;
			}

			// All clear, store the stat.
			$stats['sizes']['full'] = (object) $this->array_fill_placeholders( $this->get_size_signature(), (array) $response['data'] );
		}

		// Make sure we have the correct API details.
		if ( isset( $response ) && isset( $response['data'] ) && ( empty( $stats['stats']['api_version'] ) || - 1 === $stats['stats']['api_version'] ) ) {
			$stats['stats']['api_version'] = $response['data']->api_version;
			$stats['stats']['lossy']       = $response['data']->lossy;
			$stats['stats']['keep_exif']   = ! empty( $response['data']->keep_exif ) ? $response['data']->keep_exif : 0;
		}

		// Set smush status for all the images, store it in wp-smpro-smush-data.
		$existing_stats = get_post_meta( $attachment_id, self::$smushed_meta_key, true );

		if ( ! empty( $existing_stats ) ) {
			// Update stats for each size.
			if ( isset( $existing_stats['sizes'] ) && ! empty( $stats['sizes'] ) ) {
				foreach ( $existing_stats['sizes'] as $size_name => $size_stats ) {
					// If stats for a particular size doesn't exists.
					if ( empty( $stats['sizes'][ $size_name ] ) ) {
						$stats['sizes'][ $size_name ] = $existing_stats['sizes'][ $size_name ];
					} else {
						$existing_stats_size = (object) $existing_stats['sizes'][ $size_name ];

						// Store the original image size.
						$stats['sizes'][ $size_name ]->size_before = ( ! empty( $existing_stats_size->size_before ) && $existing_stats_size->size_before > $stats['sizes'][ $size_name ]->size_before ) ? $existing_stats_size->size_before : $stats['sizes'][ $size_name ]->size_before;

						// Update compression percent and bytes saved for each size.
						$stats['sizes'][ $size_name ]->bytes   = $stats['sizes'][ $size_name ]->bytes + $existing_stats_size->bytes;
						$stats['sizes'][ $size_name ]->percent = $this->calculate_percentage( $stats['sizes'][ $size_name ], $existing_stats_size );
					}
				}
			}

			// Keep WebP flag.
			if ( isset( $existing_stats['webp_flag'] ) ) {
				$stats['webp_flag'] = $existing_stats['webp_flag'];
			}
		}

		// Sum Up all the stats.
		$stats = WP_Smush::get_instance()->core()->total_compression( $stats );

		// If there was any compression and there was no error during optimization.
		if ( isset( $stats['stats']['bytes'] ) && $stats['stats']['bytes'] >= 0 ) {
			/**
			 * Runs if the image optimization was successful.
			 *
			 * @param int   $attachment_id  Image ID.
			 * @param array $stats          Smush stats for the image.
			 * @param array $meta           Attachment meta.
			 */
			do_action( 'wp_smush_image_optimised', $attachment_id, $stats, $meta );
		}

		update_post_meta( $attachment_id, self::$smushed_meta_key, $stats );

		return $meta;
	}

	/**
	 * Calculate saving percentage from existing and current stats
	 *
	 * @param object|string $stats           Stats object.
	 * @param object|string $existing_stats  Existing stats object.
	 *
	 * @return float
	 */
	public function calculate_percentage( $stats = '', $existing_stats = '' ) {
		if ( empty( $stats ) || empty( $existing_stats ) ) {
			return 0;
		}
		$size_before = ! empty( $stats->size_before ) ? $stats->size_before : $existing_stats->size_before;
		$size_after  = ! empty( $stats->size_after ) ? $stats->size_after : $existing_stats->size_after;
		$savings     = $size_before - $size_after;
		if ( $savings > 0 ) {
			$percentage = ( $savings / $size_before ) * 100;
			$percentage = $percentage > 0 ? round( $percentage, 2 ) : $percentage;

			return $percentage;
		}

		return 0;
	}

	/**
	 * Fix SSL CA Certificate issue.
	 *
	 * @since 3.9.6
	 *
	 * Check for use of http url (Hostgator mostly) - got it from smush_image.
	 */
	public function fix_ssl_ca_certificate_error() {
		// Return if the member defined it.
		if ( defined( 'WP_SMUSH_API_HTTP' ) ) {
			return;
		}
		static $use_http;
		/**
		 * Fix for Hostgator.
		 * Check for use of http url (Hostgator mostly).
		 */
		if ( is_null( $use_http ) ) {
			$use_http = $this->settings->get_setting( 'wp-smush-use_http', false );
		}

		if ( $use_http ) {
			define( 'WP_SMUSH_API_HTTP', 'http://smushpro.wpmudev.com/1.0/' );
		}
	}

	/**
	 * Add action when we don't smush an image,
	 * or get any errors while smushing.
	 *
	 * @param  int      $attachment_id Attachment ID.
	 * @param  WP_Error $errors an instance of WP_Error.
	 * @param  mixed    $result The data to return.
	 * @return mixed
	 */
	private function no_smushit( $attachment_id, $errors, $result = null ) {
		do_action( 'wp_smush_no_smushit', $attachment_id, $errors );
		return isset( $result ) ? $result : false;
	}

	/**
	 * Smush image
	 *
	 * @since 3.9.6
	 *
	 * @param int      $attachment_id  Attachment ID.
	 * @param array    $ref_meta Original metadata (passed by reference).
	 * @param WP_Error $ref_errors WP_Error (passed by reference).
	 *
	 * We need to detect the response status by using $ref_errors->has_errors().
	 *
	 * @return mixed Returns response data, TRUE if smushed the file, or FALSE with error(s).
	 */
	public function smushit( $attachment_id, &$ref_meta, &$ref_errors ) {
		/**
		 * Prevent infinite loop when someone call
		 * wp_generate_attachment_metadata inside smushit.
		 *
		 * By default, we already avoid it via set in-progress,
		 * but it's better to prevent it from another attachment file from third party and issue from object cache too.
		 */
		if ( $this->prevent_infinite_loop ) {
			return $this->no_smushit( $attachment_id, $ref_errors );
		}

		// Handle errors.
		if ( ! $ref_errors || ! is_wp_error( $ref_errors ) ) {
			$ref_errors = new WP_Error();
		}

		/**
		 * Error code sample.
		 *
		 * $ref_errors->add(
		 *      'error_code',
		 *      'error_message',
		 *      array(
		 *          'file_name' => 'cleaned file path',
		 *      )
		 * );
		 */

		$attachment_id = (int) $attachment_id;
		if ( $attachment_id < 1 ) {
			$ref_errors->add(
				'missing_id',
				__( 'No attachment ID was received.', 'wp-smushit' ),
				array(
					'file_name'     => 'undefined',
				)
			);
			return $this->no_smushit( $attachment_id, $ref_errors );
		}

		// Check if the file is ignored.
		if ( Helper::is_ignored( $attachment_id ) ) {
			$ref_errors->add(
				'ignored',
				__( 'Skip ignored file.', 'wp-smushit' ),
				array(
					'file_name'     => sprintf(
						/* translators: %d - attachment ID */
						esc_html__( 'undefined (attachment ID: %d)', 'wp-smushit' ),
						(int) $attachment_id
					),
				)
			);
			return $this->no_smushit( $attachment_id, $ref_errors );
		}

		// Return the status if the file is in progress.
		if ( Helper::file_in_progress( $attachment_id ) ) {
			$ref_errors->add(
				'in_progress',
				__( 'File is in progress.', 'wp-smushit' ),
				array(
					'file_name'     => sprintf(
						/* translators: %d - attachment ID */
						esc_html__( 'undefined (attachment ID: %d)', 'wp-smushit' ),
						(int) $attachment_id
					),
				)
			);
			return $this->no_smushit( $attachment_id, $ref_errors );
		}

		// Image metadata.
		if ( empty( $ref_meta ) ) {
			// We use unfiltered metadata.
			$ref_meta = wp_get_attachment_metadata( $attachment_id, true );
		}
		/**
		 * This is often not set when images are imported to the database, without properly adding the meta values.
		 * Causes PHP Warning: Illegal string offset 'file' message.
		 */
		if ( ! is_array( $ref_meta ) || ! isset( $ref_meta['file'] ) ) {
			$ref_errors->add(
				'no_file_meta',
				__( 'No file data found in image meta', 'wp-smushit' ),
				array(
					'file_name'     => sprintf(
						/* translators: %d - attachment ID */
						esc_html__( 'undefined (attachment ID: %d)', 'wp-smushit' ),
						(int) $attachment_id
					),
				)
			);
			return $this->no_smushit( $attachment_id, $ref_errors );
		}

		// Try to get the file name from path.
		$file_name = explode( '/', $ref_meta['file'] );

		if ( is_array( $file_name ) ) {
			$file_name = array_pop( $file_name );
		} else {
			$file_name = $ref_meta['file'];
		}

		/**
		 * Filter: wp_smush_image
		 *
		 * Whether to smush the given attachment id or not
		 *
		 * @param bool $skip  Bool, whether to Smush image or not.
		 * @param int  $ID    Attachment Id, Attachment id of the image being processed.
		 */
		if ( ! apply_filters( 'wp_smush_image', true, $attachment_id ) ) {
			$ref_errors->add(
				'skipped',
				esc_html__( 'Skipped with wp_smush_image filter', 'wp-smushit' ),
				array(
					'file_name' => Helper::get_image_media_link( $attachment_id, $file_name ),
				)
			);
			return $this->no_smushit( $attachment_id, $ref_errors );
		}

		// Get the file path for backup.
		$file_path = Helper::get_attached_file( $attachment_id );// S3+.

		// If the file doesn't exist, return.
		if ( ! file_exists( $file_path ) ) {
			$ref_errors->add(
				'not_found',
				esc_html__( 'Image not found.', 'wp-smushit' ),
				array(
					'file_name' => Helper::get_image_media_link( $attachment_id, $file_name ),
				)
			);
			return $this->no_smushit( $attachment_id, $ref_errors );
		}

		// Check if file is animated, return.
		if ( Helper::check_animated_status( $file_path, $attachment_id ) ) {
			$ref_errors->add(
				'animated',
				esc_html__( 'Skip animate file.', 'wp-smushit' ),
				array(
					'file_name' => Helper::get_image_media_link( $attachment_id, $file_name ),
				)
			);
			return $this->no_smushit( $attachment_id, $ref_errors );
		}

		// Set prevent_infinite_loop before adding some actions, only return after resetting this value.
		$this->prevent_infinite_loop = true;

		/**
		 * Fires before Smushing a file.
		 *
		 * @param int $attachment_id Attachment ID.
		 * @param array $ref_meta Metadata.
		 * @param WP_Error The WP_Error object (passed by reference).
		 *
		 * @hooked self::fix_ssl_ca_certificate_error()
		 * @hooked Smush\Core\Integrations\S3::activate_smush_mode()
		 */
		do_action_ref_array( 'wp_smush_before_smush_file', array( $attachment_id, $ref_meta, &$ref_errors ) );

		// Only Smush if there is no error from third party.
		$has_error = $ref_errors->has_errors();
		if ( ! $has_error ) {
			// Set a transient to avoid multiple request.
			Helper::lock_file_before_doing( 'smush', $attachment_id );

			// Is doing wp_generate_attachment_metadata.
			$generating_metadata = doing_filter( 'wp_generate_attachment_metadata' );

			// Nothing to smush if that is generating metadata while disabling auto-smush.
			if ( $generating_metadata && ! $this->is_auto_smush_enabled() ) {
				// Remove stats and update cache.
				WP_Smush::get_instance()->core()->remove_stats( $attachment_id );
			} else {
				// We only take backup before smushing image.
				WP_Smush::get_instance()->core()->mod->backup->create_backup( $file_path, $attachment_id );
				// While uploading from Mobile App or other sources, admin_init action may not fire.
				// So we need to manually initialize those.
				if ( $generating_metadata ) {
					WP_Smush::get_instance()->core()->mod->resize->initialize( true );
				}
				// Send image for resizing, if enabled resize first before any other operation.
				$updated_meta = $this->resize_image( $attachment_id, $ref_meta );

				/**
				 * Convert PNGs to JPG, it should be run with resize_image in order to retrieve the transparent status from the cache.
				 *
				 * @see SMUSH-1027
				 */
				$updated_meta = WP_Smush::get_instance()->core()->mod->png2jpg->png_to_jpg( $attachment_id, $updated_meta );

				$ref_meta = ! empty( $updated_meta ) ? $updated_meta : $ref_meta;

				// Convert to webp.
				$webp_files = WP_Smush::get_instance()->core()->mod->webp->convert_to_webp( $attachment_id, $ref_meta );
				// Handle webp errors.
				if ( is_wp_error( $webp_files ) ) {
					$ref_errors = $webp_files;
				}

				// Smush the image.
				$smush = $this->resize_from_meta_data( $attachment_id, $ref_meta );
				// Handle compress errors.
				if ( is_wp_error( $smush ) ) {
					// Handle WP_Error.
					$ref_errors->merge_from( $smush );
				}
			}
		}

		/**
		 * Fires after Smushing a file.
		 *
		 * @param int $attachment_id Attachment ID.
		 * @param array $ref_meta Metadata.
		 * @param WP_Error The WP_Error object (passed by reference).
		 *
		 * @hooked Smush\Core\Integrations\S3::release_smush_mode()
		 * @hooked Smush\Core\Integrations\S3::maybe_remove_sizes_from_s3_upload()
		 */
		do_action_ref_array( 'wp_smush_after_smush_file', array( $attachment_id, $ref_meta, &$ref_errors ) );

		// Maybe update metadata after smushing image.
		$has_error = $has_error || $ref_errors && is_wp_error( $ref_errors ) && $ref_errors->has_errors();
		// Update the metadata if there are no errors or converted PNG2JPG or resized image.
		if ( isset( $generating_metadata ) && ! $generating_metadata && ( ! $has_error || did_action( 'wp_smush_png_jpg_converted' ) || did_action( 'wp_smush_image_resized' ) ) ) {
			Helper::wp_update_attachment_metadata( $attachment_id, $ref_meta );
		}

		// Log all errors.
		if ( $has_error ) {
			Helper::logger()->error( $ref_errors->errors );
		}

		// Delete the transient after attachment meta is updated.
		Helper::release_file_after_doing( 'smush', $attachment_id );

		// Reset prevent infinite loop.
		$this->prevent_infinite_loop = null;

		return $has_error ? $this->no_smushit( $attachment_id, $ref_errors ) : true;
	}

	/**
	 * Read the image paths from an attachment's metadata and process each image with wp_smushit().
	 *
	 * @param array $meta  Attachment metadata.
	 * @param int   $id    Attachment ID.
	 *
	 * @return mixed
	 */
	public function smush_image( $meta, $id ) {
		// We need to check if this call originated from Gutenberg and allow only media.
		if ( Helper::is_non_rest_media() ) {
			// If not - return image metadata.
			return $this->no_smushit( $id, null, $meta );
		}

		$upload_attachment    = filter_input( INPUT_POST, 'action', FILTER_SANITIZE_SPECIAL_CHARS );
		$is_upload_attachment = 'upload-attachment' === $upload_attachment || isset( $_POST['post_id'] );// phpcs:ignore

		// Our async task runs when action is upload-attachment and post_id found. So do not run on these conditions.
		if ( $is_upload_attachment && defined( 'WP_SMUSH_ASYNC' ) && WP_SMUSH_ASYNC ) {
			return $meta;
		}

		/**
		 * Smush image.
		 *
		 * @since 3.9.6
		 *
		 * @param int      $id  Attachment ID.
		 * @param array    $meta Image metadata (passed by reference).
		 * @param WP_Error $errors WP_Error (passed by reference).
		 */
		$this->smushit( $id, $meta, $errors );

		return $meta;
	}

	/**
	 * Smush single images
	 *
	 * @param int  $attachment_id  Attachment ID.
	 * @param bool $return         Return/echo the stats.
	 *
	 * @return array|string
	 */
	public function smush_single( $attachment_id, $return = false ) {
		/**
		 * If the smushing option is already set, return the status.
		 *
		 * @since 3.9.6
		 * If it's not in ajax we are already handled it inside self::smushit().
		 */
		if ( ! $return && $attachment_id > 0 && Helper::file_in_progress( $attachment_id ) ) {
			// Get the button status.
			$status = WP_Smush::get_instance()->library()->generate_markup( $attachment_id );
			wp_send_json_success( $status );
		}

		// Get the image metadata from $_POST.
		$original_meta = ! empty( $_POST['metadata'] ) ? Helper::format_meta_from_post( $_POST['metadata'] ) : '';

		/**
		 * Smush image.
		 *
		 * @since 3.9.6
		 *
		 * @param int      $attachment_id  Attachment ID.
		 * @param array    $original_meta Image metadata (passed by reference).
		 * @param WP_Error $errors WP_Error (passed by reference).
		 */
		$this->smushit( $attachment_id, $original_meta, $errors );

		// Send JSON response if we are not supposed to return the results.
		if ( $errors && is_wp_error( $errors ) && $errors->has_errors() ) {
			if ( $return ) {
				return array( 'error' => $errors->get_error_message() );
			}

			// Prepare data for ajax.
			$error_code = $errors->get_error_code();
			$error_data = $errors->get_error_data();
			$status = array(
				'error' => $error_code,
				'error_msg'    => '<p class="wp-smush-error-message">' . Helper::filter_error( $errors->get_error_message( $error_code ), $attachment_id ) . '</p>',
				'show_warning' => (int) $this->show_warning(),
			);

			// Add error data (file_name) to status.
			if ( $error_data && is_array( $error_data ) ) {
				$status = array_merge( $error_data, $status );
			}

			// Send data.
			wp_send_json_error( $status );
		}

		// Get the button status.
		$status = WP_Smush::get_instance()->library()->generate_markup( $attachment_id );

		$this->update_resmush_list( $attachment_id );
		\Smush\Core\Core::add_to_smushed_list( $attachment_id );
		if ( $return ) {
			return $status;
		}

		wp_send_json_success( $status );
	}

	/**
	 * If auto smush is set to true or not, default is true
	 *
	 * @return int|mixed
	 */
	public function is_auto_smush_enabled() {
		$auto_smush = $this->settings->get( 'auto' );

		// Keep the auto smush on by default.
		if ( ! isset( $auto_smush ) ) {
			$auto_smush = 1;
		}

		return $auto_smush;
	}

	/**
	 * Deletes all the backup files when an attachment is deleted
	 * Update resmush List
	 * Update Super Smush image count
	 *
	 * @param int $image_id  Attachment ID.
	 *
	 * @return bool|void
	 */
	public function delete_images( $image_id ) {
		// Update the savings cache.
		WP_Smush::get_instance()->core()->get_savings( 'resize' );

		// Update the savings cache.
		WP_Smush::get_instance()->core()->get_savings( 'pngjpg' );

		// If no image id provided.
		if ( empty( $image_id ) ) {
			return false;
		}

		// Check and Update resmush list.
		$resmush_list = get_option( 'wp-smush-resmush-list' );
		if ( $resmush_list ) {
			$this->update_resmush_list( $image_id, 'wp-smush-resmush-list' );
		}

		/** Delete Backups  */
		// Check if we have any smush data for image.
		WP_Smush::get_instance()->core()->mod->backup->delete_backup_files( $image_id );

		/**
		 * Delete webp.
		 *
		 * Run WebP::delete_images always even when the module is deactivated.
		 *
		 * @since 3.8.0
		 */
		WP_Smush::get_instance()->core()->mod->webp->delete_images( $image_id, false );
	}

	/**
	 * Calculate saving percentage for a given size stats
	 *
	 * @param object $stats  Stats object.
	 *
	 * @return float|int
	 */
	private function calculate_percentage_from_stats( $stats ) {
		if ( empty( $stats ) || ! isset( $stats->size_before, $stats->size_after ) ) {
			return 0;
		}

		$savings = $stats->size_before - $stats->size_after;
		if ( $savings > 0 ) {
			$percentage = ( $savings / $stats->size_before ) * 100;
			$percentage = $percentage > 0 ? round( $percentage, 2 ) : $percentage;

			return $percentage;
		}

		return 0;
	}

	/**
	 * Perform the resize operation for the image
	 *
	 * @param int   $attachment_id  Attachment ID.
	 * @param array $meta           Attachment meta.
	 *
	 * @return mixed
	 */
	public function resize_image( $attachment_id, $meta ) {
		if ( empty( $attachment_id ) || empty( $meta ) ) {
			return $meta;
		}

		return WP_Smush::get_instance()->core()->mod->resize->auto_resize( $attachment_id, $meta );
	}

	/**
	 * Send a smush request for the attachment
	 *
	 * @param int $id  Attachment ID.
	 */
	public function wp_smush_handle_async( $id ) {
		// If we don't have image id or auto Smush is disabled, return.
		if ( empty( $id ) || ! $this->is_auto_smush_enabled() ) {
			return;
		}

		// Try to use smushit.
		$this->smush_single( $id, true );
	}

	/**
	 * Send a smush request for the attachment
	 *
	 * @param int   $id         Attachment ID.
	 * @param array $post_data  Post data.
	 */
	public function wp_smush_handle_editor_async( $id, $post_data ) {
		// If we don't have image id, or the smush is already in progress for the image, return.
		if ( empty( $id ) || Helper::file_in_progress( $id ) ) {
			return;
		}

		// If auto Smush is disabled.
		if ( ! $this->is_auto_smush_enabled() ) {
			return;
		}

		/**
		 * Filter: wp_smush_image
		 *
		 * Whether to smush the given attachment id or not
		 *
		 * @param bool $skip  Whether to Smush image or not.
		 * @param int  $id    Attachment ID of the image being processed.
		 */
		if ( ! apply_filters( 'wp_smush_image', true, $id ) ) {
			return;
		}

		// If filepath is not set or file doesn't exist.
		if ( ! isset( $post_data['filepath'] ) || ! file_exists( $post_data['filepath'] ) ) {
			return;
		}

		$res = $this->do_smushit( $post_data['filepath'] );

		if ( is_wp_error( $res ) || empty( $res['success'] ) || ! $res['success'] ) {
			// Logged the error inside do_smushit.
			return;
		}

		// Update stats if it's the full size image. Return if it's not the full image size.
		if ( $post_data['filepath'] != get_attached_file( $post_data['postid'] ) ) {
			return;
		}

		// Get the existing Stats.
		$smush_stats = get_post_meta( $post_data['postid'], self::$smushed_meta_key, true );
		$stats_full  = ! empty( $smush_stats['sizes'] ) && ! empty( $smush_stats['sizes']['full'] ) ? $smush_stats['sizes']['full'] : '';

		if ( empty( $stats_full ) ) {
			return;
		}

		// store the original image size.
		$stats_full->size_before = ( ! empty( $stats_full->size_before ) && $stats_full->size_before > $res['data']->before_size ) ? $stats_full->size_before : $res['data']->before_size;
		$stats_full->size_after  = $res['data']->after_size;

		// Update compression percent and bytes saved for each size.
		$stats_full->bytes = $stats_full->size_before - $stats_full->size_after;

		$stats_full->percent          = $this->calculate_percentage_from_stats( $stats_full );
		$smush_stats['sizes']['full'] = $stats_full;

		// Update stats.
		update_post_meta( $post_data['postid'], self::$smushed_meta_key, $smush_stats );
	}

	/**
	 * Make sure we treat the scaled image as an attachment size, rather than the original uploaded image.
	 *
	 * @since 3.9.1
	 *
	 * @param array $meta           Attachment meta data.
	 * @param int   $attachment_id  Attachment ID.
	 *
	 * @return array
	 */
	public function add_scaled_to_meta( $meta, $attachment_id ) {
		// If the image is not a scaled version - do nothing.
		if ( false === strpos( $meta['file'], '-scaled.' ) || ! isset( $meta['original_image'] ) || isset( $meta['sizes']['wp_scaled'] ) ) {
			return $meta;
		}

		$meta['sizes']['wp_scaled'] = array(
			'file'      => basename( $meta['file'] ),
			'width'     => $meta['width'],
			'height'    => $meta['height'],
			'mime-type' => get_post_mime_type( $attachment_id ),
		);

		return $meta;
	}

}
