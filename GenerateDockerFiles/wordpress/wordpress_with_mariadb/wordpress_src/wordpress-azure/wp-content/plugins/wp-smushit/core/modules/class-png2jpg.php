<?php
/**
 * PNG to JPG conversion: Png2jpg class
 *
 * @package Smush\Core\Modules
 *
 * @version 2.4
 *
 * @author Umesh Kumar <umesh@incsub.com>
 *
 * @copyright (c) 2016, Incsub (http://incsub.com)
 */

namespace Smush\Core\Modules;

use Exception;
use Imagick;
use Smush\Core\Helper;
use WP_Smush;

if ( ! defined( 'WPINC' ) ) {
	die;
}

/**
 * Class Png2jpg
 */
class Png2jpg extends Abstract_Module {

	/**
	 * Module slug.
	 *
	 * @var string
	 */
	protected $slug = 'png_to_jpg';

	/**
	 * Whether module is pro or not.
	 *
	 * @var string
	 */
	protected $is_pro = true;

	/**
	 * Init method.
	 *
	 * @since 3.0
	 */
	public function init() {

		// Only apply filters for PRO + activated PNG2JPG.
		if ( $this->is_active() ) {
			/**
			 * Add a filter to check if the image should resmush.
			 * While checking resmush, we priority to check PNG2JPG before checking resize
			 * to optimize for the case, the site is activating S3 and doesn't save files on the server:
			 * 1. If there is a PNG file, we will need to download it so when we check with resize, we don't need to download it again.
			 * 2. If there is not a PNG file, we don't need to download this file,
			 * and on resize method we will try to download the file content from url if it's necessary.
			 */
			add_filter( 'wp_smush_should_resmush', array( $this, 'should_resmush' ), 9, 2 );

			/**
			 * Save can be convert to jpg status before resizing the image.
			 */
			add_filter( 'wp_smush_resize_sizes', array( $this, 'cache_can_be_converted_status' ), 0, 3 );
		}
	}

	/**
	 * Check if Imagick is available or not
	 *
	 * @return bool True/False Whether Imagick is available or not
	 */
	private function supports_imagick() {
		if ( ! class_exists( '\Imagick' ) ) {
			return false;
		}

		return true;
	}

	/**
	 * Check if GD is loaded
	 *
	 * @return bool True/False Whether GD is available or not
	 */
	private function supports_gd() {
		if ( ! function_exists( 'gd_info' ) ) {
			return false;
		}

		return true;
	}

	/**
	 * Save can be converted status before resizing the image,
	 * because the the image might be lost the undefined-transparent behavior after resizing.
	 *
	 * @see WP_Image_Editor_Imagick::thumbnail_image()
	 * WP Resize function will convert Imagick::ALPHACHANNEL_UNDEFINED -> Imagick::ALPHACHANNEL_OPAQUE.
	 *
	 * @param array  $sizes      Array of sizes containing max width and height for all the uploaded images.
	 * @param string $file_path  Image file path.
	 * @param int    $id         Image id.
	 *
	 * @return array the Original $sizes.
	 *
	 * @since 3.9.6
	 */
	public function cache_can_be_converted_status( $sizes, $file_path, $id ) {
		// Call can_be_converted and cache the status.
		$this->can_be_converted( $id, 'full', '', $file_path );
		// Always return $sizes.
		return $sizes;
	}

	/**
	 * Checks if the Given PNG file is transparent or not
	 *
	 * @param string $id    Attachment ID.
	 * @param string $file  File path for the attachment.
	 *
	 * @return bool|int
	 */
	private function is_transparent( $id = '', $file = '' ) {
		// No attachment id/ file path, return.
		if ( empty( $id ) && empty( $file ) ) {
			return false;
		}

		if ( empty( $file ) ) {
			// This downloads the file from S3 when S3 is enabled.
			$file = Helper::get_attached_file( $id );
		}

		// Check if File exists.
		if ( empty( $file ) || ! file_exists( $file ) ) {
			Helper::logger()->png2jpg()->info( sprintf( 'File [%s(%d)] is empty or does not exist.', Helper::clean_file_path( $file ), $id ) );
			return false;
		}

		$transparent = '';

		// Try to get transparency using Imagick.
		if ( $this->supports_imagick() ) {
			try {
				$im = new Imagick( $file );

				return $im->getImageAlphaChannel();
			} catch ( Exception $e ) {
				Helper::logger()->png2jpg()->error( 'Imagick: Error in checking PNG transparency ' . $e->getMessage() );
			}
		} else {
			// Simple check.
			// Src: http://camendesign.com/code/uth1_is-png-32bit.
			if ( ord( file_get_contents( $file, false, null, 25, 1 ) ) & 4 ) {
				Helper::logger()->png2jpg()->info( sprintf( 'File [%s(%d)] is an PNG 32-bit.', Helper::clean_file_path( $file ), $id ) );
				return true;
			}
			// Src: http://www.jonefox.com/blog/2011/04/15/how-to-detect-transparency-in-png-images/.
			$contents = file_get_contents( $file );
			if ( stripos( $contents, 'PLTE' ) !== false && stripos( $contents, 'tRNS' ) !== false ) {
				Helper::logger()->png2jpg()->info( sprintf( 'File [%s(%d)] is an PNG 8-bit.', Helper::clean_file_path( $file ), $id ) );
				return true;
			}

			// If both the conditions failed, that means not transparent.
			return false;

		}

		// If Imagick is installed, and the code exited due to some error.
		// Src: StackOverflow.
		if ( empty( $transparent ) && $this->supports_gd() ) {
			// Check for transparency using GD.
			$i       = imagecreatefrompng( $file );
			$palette = ( imagecolortransparent( $i ) < 0 );
			if ( $palette ) {
				return true;
			}
		}

		return false;
	}

	/**
	 * Check if given attachment id can be converted to JPEG or not
	 *
	 * @param string $id    Atachment ID.
	 * @param string $size  Image size.
	 * @param string $mime  Mime type.
	 * @param string $file  File.
	 *
	 * @since 3.9.6 We removed the private method should_convert
	 * and we also handled the case which we need to delete the download file inside S3.
	 *
	 * Note, we also used this for checking resmush, so we only download the attached file (s3)
	 * if it's necessary (self::is_transparent()). Check the comment on self::__construct() for detail.
	 *
	 * @return bool True/False Can be converted or not
	 */
	public function can_be_converted( $id = '', $size = 'full', $mime = '', $file = '' ) {
		// If PNG2JPG not enabled, or is not smushable, return.
		if ( ! $this->is_active() || ! Helper::is_smushable( $id ) ) {
			return false;
		}
		// Check it from the cache for full size.
		if ( 'full' === $size && null !== Helper::cache_get( $id, 'png2jpg_can_be_converted' ) ) {
			return Helper::cache_get( $id, 'png2jpg_can_be_converted' );
		}

		// False if not a PNG.
		$mime = empty( $mime ) ? get_post_mime_type( $id ) : $mime;
		if ( 'image/png' !== $mime && 'image/x-png' !== $mime ) {
			return false;
		}

		// Return if Imagick and GD is not available.
		if ( ! $this->supports_imagick() && ! $this->supports_gd() ) {
			Helper::logger()->png2jpg()->warning( 'The site does not support Imagick or GD.' );
			return false;
		}

		// If already tried the conversion.
		if ( get_post_meta( $id, 'wp-smush-pngjpg_savings', true ) ) {
			Helper::logger()->png2jpg()->info( sprintf( 'File [%s(%d)] already tried the conversion.', Helper::clean_file_path( $file ), $id ) );
			return false;
		}

		// Check if registered size is supposed to be converted or not.
		if ( 'full' !== $size && WP_Smush::get_instance()->core()->mod->smush->skip_image_size( $size ) ) {
			return false;
		}

		// Make sure $file is not empty.
		if ( empty( $file ) ) {
			$file = Helper::get_attached_file( $id );// S3+.
		}

		/**
		 * Filter whether to convert the PNG to JPG or not
		 *
		 * @since 2.4
		 *
		 * @param bool $should_convert Current choice for image conversion
		 *
		 * @param int $id Attachment id
		 *
		 * @param string $file File path for the image
		 *
		 * @param string $size Image size being converted
		 */
		$should_convert = apply_filters( 'wp_smush_convert_to_jpg', ! $this->is_transparent( $id, $file ), $id, $file, $size );

		if ( 'full' === $size ) {
			/**
			 * We used this method inside Backup::create_backup(), Smush function, and filter wp_smush_resize_sizes,
			 * so cache the result to avoid to check it again.
			 */
			Helper::cache_set( $id, $should_convert, 'png2jpg_can_be_converted' );
		}

		return $should_convert;
	}

	/**
	 * Check whether to resmush image or not.
	 *
	 * @since 3.9.6
	 *
	 * @usedby Smush\App\Ajax::scan_images()
	 *
	 * @param bool $should_resmush Current status.
	 * @param int  $attachment_id  Attachment ID.
	 * @return bool|string png2jpg|TRUE|FALSE
	 */
	public function should_resmush( $should_resmush, $attachment_id ) {
		if ( ! $should_resmush && $this->can_be_converted( $attachment_id ) ) {
			$should_resmush = 'png2jpg';
		}

		return $should_resmush;
	}

	/**
	 * Update the image URL, MIME Type, Attached File, file path in Meta, URL in post content
	 *
	 * @param string $id      Attachment ID.
	 * @param string $o_file  Original File Path that has to be replaced.
	 * @param string $n_file  New File Path which replaces the old file.
	 * @param string $meta    Attachment Meta.
	 * @param string $size_k  Image Size.
	 * @param string $o_type  Operation Type "conversion", "restore".
	 *
	 * @return array  Attachment Meta with updated file path.
	 */
	public function update_image_path( $id, $o_file, $n_file, $meta, $size_k, $o_type = 'conversion' ) {
		// Upload Directory.
		$upload_dir = wp_upload_dir();

		// Upload Path.
		$upload_path = trailingslashit( $upload_dir['basedir'] );

		$dir_name = pathinfo( $o_file, PATHINFO_DIRNAME );

		// Full Path to new file.
		$n_file_path = path_join( $dir_name, $n_file );

		// Current URL for image.
		$o_url = wp_get_attachment_url( $id );

		// Update URL for image size.
		if ( 'full' !== $size_k ) {
			$base_url = dirname( $o_url );
			$o_url    = $base_url . '/' . basename( $o_file );
		}

		// Update File path, Attached File, GUID.
		$meta = empty( $meta ) ? wp_get_attachment_metadata( $id ) : $meta;
		$mime = Helper::get_mime_type( $n_file_path );

		/**
		 * If there's no fileinfo extension installed, the mime type will be returned as false.
		 * As a fallback, we set it manually.
		 *
		 * @since 3.8.3
		 */
		if ( false === $mime ) {
			$mime = 'conversion' === $o_type ? 'image/jpeg' : 'image/png';
		}

		$del_file = true;
		// Update File Path, Attached file, Mime Type for Image.
		if ( 'full' === $size_k ) {
			if ( ! empty( $meta ) ) {
				$new_file     = str_replace( $upload_path, '', $n_file_path );
				$meta['file'] = $new_file;

				// Update Attached File.
				if ( ! update_attached_file( $id, $meta['file'] ) ) {
					$del_file = false;
				}
			}

			// Update Mime type.
			if ( ! wp_update_post(
				array(
					'ID'             => $id,
					'post_mime_type' => $mime,
				)
			) ) {
				$del_file = false;
			}
		} else {
			$meta['sizes'][ $size_k ]['file']      = basename( $n_file );
			$meta['sizes'][ $size_k ]['mime-type'] = $mime;
		}

		// To be called after the attached file key is updated for the image.
		if ( ! $this->update_image_url( $id, $size_k, $n_file, $o_url ) ) {
			$del_file = false;
		}

		/**
		 * Delete the Original files if backup not enabled
		 * We only delete the file if we don't have any issues while updating the DB.
		 * SMUSH-1088?focusedCommentId=92914.
		 */
		if ( $del_file && 'conversion' === $o_type ) {
			// We might need to backup the full size file, will delete it later if we don't need to use it for backup.
			if ( 'full' !== $size_k ) {
				/**
				 * We only need to keep the original file as a backup file.
				 * and try to delete this file on cloud too, e.g S3.
				 */
				Helper::delete_permanently( $o_file, $id );
			}
		}

		return $meta;
	}

	/**
	 * Replace the file if there are savings, and return savings
	 *
	 * @param string $file    Original File Path.
	 * @param array  $result  Array structure.
	 * @param string $n_file  Updated File path.
	 *
	 * @return array
	 */
	private function replace_file( $file = '', $result = array(), $n_file = '' ) {
		if ( empty( $file ) || empty( $n_file ) ) {
			return $result;
		}

		// Get the file size of original image.
		$o_file_size = filesize( $file );

		$n_file = path_join( dirname( $file ), $n_file );

		$n_file_size = filesize( $n_file );

		// If there aren't any savings return.
		if ( $n_file_size >= $o_file_size ) {
			// Delete the JPG image and return.
			@unlink( $n_file );
			Helper::logger()->png2jpg()->notice( sprintf( 'The new file [%s](%s) is larger than the original file [%s](%s).', Helper::clean_file_path( $n_file ), size_format( $n_file_size ), Helper::clean_file_path( $file ), size_format( $o_file_size ) ) );

			return $result;
		}

		// Get the savings.
		$savings = $o_file_size - $n_file_size;

		// Store Stats.
		$savings = array(
			'bytes'       => $savings,
			'size_before' => $o_file_size,
			'size_after'  => $n_file_size,
		);

		$result['savings'] = $savings;

		return $result;
	}

	/**
	 * Perform the conversion process, using WordPress Image Editor API
	 *
	 * @param string $id    Attachment ID.
	 * @param string $file  Attachment File path.
	 * @param string $meta  Attachment meta.
	 * @param string $size  Image size, default empty for full image.
	 *
	 * @return array $result array(
	 *  'meta'  => array Update Attachment metadata
	 *  'savings'   => Reduction of Image size in bytes
	 * )
	 */
	private function convert_to_jpg( $id = '', $file = '', $meta = '', $size = 'full' ) {
		$result = array(
			'meta'    => $meta,
			'savings' => '',
		);

		// Flag: Whether the image was converted or not.
		if ( 'full' === $size ) {
			$result['converted'] = false;
		}

		// If any of the values is not set.
		if ( empty( $id ) || empty( $file ) || empty( $meta ) || ! file_exists( $file ) ) {
			Helper::logger()->png2jpg()->info( sprintf( 'Meta file [%s(%d)] is empty or file not found.', Helper::clean_file_path( $file ), $id ) );
			return $result;
		}

		$editor = wp_get_image_editor( $file );

		if ( is_wp_error( $editor ) ) {
			// Use custom method maybe.
			Helper::logger()->png2jpg()->error( sprintf( 'Image Editor cannot load file [%s(%d)]: %s.', Helper::clean_file_path( $file ), $id, $editor->get_error_message() ) );
			return $result;
		}

		$n_file = pathinfo( $file );

		if ( ! empty( $n_file['filename'] ) && $n_file['dirname'] ) {
			// Get a unique File name.
			if ( $file_detail = Helper::cache_get( $id, 'convert_to_jpg' ) ) {// phpcs:ignore
				list( $old_main_filename, $new_main_filename ) = $file_detail;
				/**
				 * Thumbnail name.
				 * E.g.
				 * test-150x150.jpg
				 * test-1-150x150.jpg
				 */
				if ( $old_main_filename !== $new_main_filename ) {
					$n_file['filename'] = str_replace( $old_main_filename, $new_main_filename, $n_file['filename'] );
				}
				$n_file['filename'] .= '.jpg';
			} else {
				$org_filename = $n_file['filename'];
				/**
				 * Get unique file name for the main file.
				 * E.g.
				 * test.png => test.jpg
				 * test.png => test-1.jpg
				 */
				$n_file['filename'] = wp_unique_filename( $n_file['dirname'], $org_filename . '.jpg' );
				Helper::cache_set( $id, array( $org_filename, pathinfo( $n_file['filename'], PATHINFO_FILENAME ) ), 'convert_to_jpg' );
			}
			$n_file = path_join( $n_file['dirname'], $n_file['filename'] );
		} else {
			Helper::logger()->png2jpg()->error( sprintf( 'Cannot retrieve the path info of file [%s(%d)].', Helper::clean_file_path( $file ), $id ) );
			return $result;
		}

		// Save PNG as JPG.
		$new_image_info = $editor->save( $n_file, 'image/jpeg' );

		// If image editor was unable to save the image, return.
		if ( is_wp_error( $new_image_info ) ) {
			return $result;
		}

		$n_file = ! empty( $new_image_info ) ? $new_image_info['file'] : '';

		// Replace file, and get savings.
		$result = $this->replace_file( $file, $result, $n_file );

		if ( ! empty( $result['savings'] ) ) {
			if ( 'full' === $size ) {
				$result['converted'] = true;
			}
			// Update the File Details. and get updated meta.
			$result['meta'] = $this->update_image_path( $id, $file, $n_file, $meta, $size );

			/**
			 *  Perform a action after the image URL is updated in post content
			 */
			do_action( 'wp_smush_image_url_changed', $id, $file, $n_file, $size );
		}

		return $result;
	}

	/**
	 * Convert a PNG to JPG, Lossless Conversion, if we have any savings
	 *
	 * @param string       $id    Image ID.
	 * @param string|array $meta  Image meta.
	 *
	 * @uses Backup::add_to_image_backup_sizes()
	 *
	 * @return mixed|string
	 *
	 * TODO: Save cumulative savings
	 */
	public function png_to_jpg( $id = '', $meta = '' ) {
		// If we don't have meta or ID, or if not a premium user.
		if ( empty( $id ) || empty( $meta ) || ! $this->is_active() || ! Helper::is_smushable( $id ) ) {
			return $meta;
		}

		$file = Helper::get_attached_file( $id );// S3+.

		// Whether to convert to jpg or not.
		$should_convert = $this->can_be_converted( $id, 'full', '', $file );

		if ( ! $should_convert ) {
			return $meta;
		}

		$result['meta'] = $meta;

		/**
		 * Allow to force convert the PNG to JPG via filter wp_smush_convert_to_jpg.
		 *
		 * @since 3.9.6
		 * @see self::can_be_converted()
		 */
		// Perform the conversion, and update path.
		$result = $this->convert_to_jpg( $id, $file, $result['meta'] );

		$savings['full'] = ! empty( $result['savings'] ) ? $result['savings'] : '';

		// If original image was converted and other sizes are there for the image, Convert all other image sizes.
		if ( $result['converted'] ) {
			if ( ! empty( $meta['sizes'] ) ) {
				$converted_thumbs = array();
				foreach ( $meta['sizes'] as $size_k => $data ) {
					// Some thumbnail sizes are using the same image path, so check if the thumbnail file is converted.
					if ( isset( $converted_thumbs[ $data['file'] ] ) ) {
						// Update converted thumbnail size.
						$result['meta']['sizes'][ $size_k ]['file']      = $result['meta']['sizes'][ $converted_thumbs[ $data['file'] ] ]['file'];
						$result['meta']['sizes'][ $size_k ]['mime-type'] = $result['meta']['sizes'][ $converted_thumbs[ $data['file'] ] ]['mime-type'];
						continue;
					}
					$s_file = path_join( dirname( $file ), $data['file'] );

					/**
					 * Check if the file exists on the server,
					 * if not, might try to download it from the cloud (s3).
					 *
					 * @since 3.9.6
					 */
					if ( ! Helper::exists_or_downloaded( $s_file, $id ) ) {
						continue;
					}
					/**
					 * Since these sizes are derived from the main png file,
					 * We can safely perform the conversion.
					 */
					$result = $this->convert_to_jpg( $id, $s_file, $result['meta'], $size_k );

					if ( ! empty( $result['savings'] ) ) {
						$savings[ $size_k ] = $result['savings'];
						/**
						 * Save converted thumbnail file, allow to try to convert the thumbnail to PNG again if it was failed.
						 */
						$converted_thumbs[ $data['file'] ] = $size_k;
					}
				}
			}

			$mod = WP_Smush::get_instance()->core()->mod;

			// Save the original File URL.
			/**
			 * Filter: wp_smush_png2jpg_enable_backup
			 *
			 * Whether to backup the PNG before converting it to JPG or not
			 *
			 * It's safe when we try to backup the PNG file before converting it to JPG when disabled backup option.
			 * But if exists the backup file, we can delete the PNG file to free up space.
			 * Note, if enabling resize the image, the backup file is a file that has already been resized, not the original file.
			 * Use this filter to disable this option:
			 * add_filter('wp_smush_png2jpg_enable_backup', '__return_false' );
			 */
			if ( $mod->backup->is_active() || apply_filters( 'wp_smush_png2jpg_enable_backup', ! $mod->backup->is_active(), $id, $file ) ) {
				if ( ! $mod->backup->maybe_backup_image( $id, $file ) ) {
					/**
					 * Delete the original file if the backup file exists.
					 *
					 * Note, we use size key smush-png2jpg-full for PNG2JPG file to support S3 private media,
					 * to remove converted JPG file after restoring in private folder.
					 *
					 * @see Smush\Core\Integrations\S3::get_object_key()
					 */
					Helper::delete_permanently( array( 'smush-png2jpg-full' => $file ), $id );// S3+.
				}
			}

			// Remove webp images created from the png version, if any.
			$mod->webp->delete_images( $id, true, $file );

			/**
			 * Do action, if the PNG to JPG conversion was successful
			 */
			do_action( 'wp_smush_png_jpg_converted', $id, $meta, $savings );

			/**
			 * The file converted to JPG,
			 * we can clear the temp cache related to this converting.
			 */
			Helper::cache_delete( 'png2jpg_can_be_converted' );
			Helper::cache_delete( 'convert_to_jpg' );
		}

		// Update the Final Stats.
		update_post_meta( $id, 'wp-smush-pngjpg_savings', $savings );

		return $result['meta'];
	}

	/**
	 * Get JPG quality from WordPress Image Editor
	 *
	 * @param string $file  File.
	 *
	 * @return int Quality for JPEG images
	 */
	private function get_quality( $file ) {
		if ( empty( $file ) ) {
			return 82;
		}
		$editor = wp_get_image_editor( $file );

		if ( ! is_wp_error( $editor ) ) {
			$quality = $editor->get_quality();
		} else {
			Helper::logger()->png2jpg()->error( sprintf( 'Image Editor cannot load image [%s].', Helper::clean_file_path( $file ) ) );
		}

		// Choose the default quality if we didn't get it.
		if ( ! isset( $quality ) || $quality < 1 || $quality > 100 ) {
			// The default quality.
			$quality = 82;
		}

		return $quality;
	}

	/**
	 * Check whether the given attachment was converted from PNG to JPG.
	 *
	 * @param int $id  Attachment ID.
	 *
	 * @since 3.9.6 Use this function to check if an image is converted from PNG to JPG.
	 * @see Backup::get_backup_file() To check the backup file.
	 *
	 * @return int|false False if the image id is empty.
	 * 0 Not yet converted, -1 Tried to convert but it failed or not saving, 1 Convert successfully.
	 */
	public function is_converted( $id ) {
		if ( empty( $id ) ) {
			return false;
		}

		$savings = get_post_meta( $id, 'wp-smush-pngjpg_savings', true );
		$is_converted = 0;
		if ( ! empty( $savings ) ) {
			$is_converted = -1;// The image was tried to convert to JPG but it failed or larger than the original file.
			if ( ! empty( $savings['full'] ) ) {
				$is_converted = 1;// The image was converted to JPG successfully.
			}
		}

		return $is_converted;
	}

	/**
	 * Update Image URL in post content
	 *
	 * @param string $id      Attachment ID.
	 * @param string $size_k  Image Size.
	 * @param string $n_file  New File Path which replaces the old file.
	 * @param string $o_url   URL to search for.
	 */
	private function update_image_url( $id, $size_k, $n_file, $o_url ) {
		if ( 'full' === $size_k ) {
			// Get the updated image URL.
			$n_url = wp_get_attachment_url( $id );
		} else {
			$n_url = trailingslashit( dirname( $o_url ) ) . basename( $n_file );
		}

		// Update In Post Content, Loop Over a set of posts to avoid the query failure for large sites.
		global $wpdb;
		// Get existing Images with current URL.
		$query = $wpdb->prepare(
			"SELECT ID, post_content FROM $wpdb->posts WHERE post_content LIKE '%%%s%%'",
			$o_url
		);

		$rows = $wpdb->get_results( $query, ARRAY_A );

		if ( empty( $rows ) || ! is_array( $rows ) ) {
			return true;
		}

		// Iterate over rows to update post content.
		$total = count( $rows );
		foreach ( $rows as $row ) {
			// replace old URLs with new URLs.
			$post_content = $row['post_content'];
			$post_content = str_replace( $o_url, $n_url, $post_content );
			// Update Post content.
			if ( $wpdb->update(
				$wpdb->posts,
				array(
					'post_content' => $post_content,
				),
				array(
					'ID' => $row['ID'],
				)
			) ) {
				$total --;
			}
			clean_post_cache( $row['ID'] );
		}

		// SMUSH-1088?focusedCommentId=92914.
		return 0 === $total;
	}

}
