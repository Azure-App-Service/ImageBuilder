<?php
/**
 * Smush backup class
 *
 * @package Smush\Core\Modules
 */

namespace Smush\Core\Modules;

use Smush\Core\Core;
use Smush\Core\Helper;
use WP_Smush;

if ( ! defined( 'WPINC' ) ) {
	die;
}

/**
 * Class Backup
 */
class Backup extends Abstract_Module {

	/**
	 * Module slug.
	 *
	 * @var string
	 */
	protected $slug = 'backup';

	/**
	 * Key for storing file path for image backup
	 *
	 * @var string
	 */
	private $backup_key = 'smush-full';

	/**
	 * Backup constructor.
	 */
	public function init() {
		// Handle Restore operation.
		add_action( 'wp_ajax_smush_restore_image', array( $this, 'restore_image' ) );

		// Handle bulk restore from modal.
		add_action( 'wp_ajax_get_image_count', array( $this, 'get_image_count' ) );
		add_action( 'wp_ajax_restore_step', array( $this, 'restore_step' ) );
	}

	/**
	 * Check if the backup file exists.
	 *
	 * @param int    $attachment_id Attachment ID.
	 * @param string $file_path Current file path.
	 * @return bool  True if the backup file exists, false otherwise.
	 */
	public function backup_exists( $attachment_id, $file_path = false ) {
		return apply_filters( 'wp_smush_backup_exists', $this->get_backup_file( $attachment_id, $file_path ), $attachment_id, $file_path );
	}

	/**
	 * Generate unique .bak file.
	 *
	 * @param string $bak_file The .bak file.
	 * @param int    $attachment_id Attachment ID.
	 * @return string Returns a unique backup file.
	 */
	private function generate_unique_bak_file( $bak_file, $attachment_id ) {
		if ( strpos( $bak_file, '.bak' ) && Helper::file_exists( $bak_file, $attachment_id ) ) {
			$count            = 1;
			$ext              = Helper::get_file_ext( $bak_file );
			$ext              = ".bak.$ext";
			$file_without_ext = rtrim( $bak_file, $ext );
			$bak_file         = $file_without_ext . '-' . $count . $ext;

			while ( Helper::file_exists( $bak_file, $attachment_id ) ) {
				$count++;
				$bak_file = $file_without_ext . '-' . $count . $ext;
			}

			return $bak_file;
		}
		return $bak_file;
	}

	/**
	 * Creates a backup of file for the given attachment path.
	 *
	 * Checks if there is an existing backup, else create one.
	 *
	 * @param string $file_path      File path.
	 * @param int    $attachment_id  Attachment ID.
	 *
	 * @return void
	 */
	public function create_backup( $file_path, $attachment_id ) {
		if ( empty( $file_path ) || empty( $attachment_id ) ) {
			return;
		}

		// If backup not enabled, return.
		if ( ! $this->is_active() ) {
			return;
		}

		/**
		 * If [ not compress original ]:
		 *    if [ is-scaled.file ]:
		 *          Backup original file.
		 *    elseif [ no-resize + no-png2jpg ]:
		 *          We don't need to backup, let user try to use regenerate plugin
		 *          to restore the compressed thumbnails size.
		 *    else: continue as compress_original.
		 * else:
		 *      We don't need to backup if we had a backup file for PNG2JPG,
		 *      or .bak file. But if the .bak file is from third party, we will generate our new backup file.
		 * end.
		 */

		// We might not need to backup the file if we're not compressing original.
		if ( ! $this->settings->get( 'original' ) ) {
			/**
			 * Add WordPress 5.3 support for -scaled images size, and those can always be used to restore.
			 * Maybe user doesn't want to auto-scale JPG from WP for some images,
			 * so we allow user to restore it even we don't Smush this image.
			 */
			if ( false !== strpos( $file_path, '-scaled.' ) && function_exists( 'wp_get_original_image_path' ) ) {
				// Scaled images already have a backup. Use that and don't create a new one.
				$file_path = Helper::get_attached_file( $attachment_id, 'backup' );// Supported S3.
				if ( file_exists( $file_path ) ) {
					/**
					 * We do not need an additional backup file if we're not compressing originals.
					 * But we need to save the original file as a backup file in the metadata to allow restoring this image later.
					 */
					$this->add_to_image_backup_sizes( $attachment_id, $file_path );
					return;
				}
			}

			$mod = WP_Smush::get_instance()->core()->mod;

			// If there is not *-scaled.jpg file, we don't need to backup the file if we don't work with original file.
			if ( ! $mod->resize->is_active() && ! $mod->png2jpg->is_active() ) {
				/**
				 * In this case, we can add the meta to save the original file as a backup file,
				 * but if there is a lot of images, might take a lot of row for postmeta table,
				 * so leave it for user to use a "regenerate thumbnail" plugin instead.
				 */
				Helper::logger()->backup()->info( sprintf( 'Not modify the original file [%s(%d)], skip the backup.', Helper::clean_file_path( $file_path ), $attachment_id ) );
				return;
			}

			$should_backup = false;

			// We should backup this image if we can resize it.
			if ( $mod->resize->is_active() && $mod->resize->should_resize( $attachment_id ) ) {
				$should_backup = true;
			}

			// We should backup this image if we can convert it from PNG to JPEG.
			if (
				! $should_backup && $mod->png2jpg->is_active() && Helper::get_file_ext( $file_path, 'png' )
				&& $mod->png2jpg->can_be_converted( $attachment_id, 'full', 'image/png', $file_path )
			) {
				$should_backup = true;
			}

			// As we don't work with the original file, so we don't back it up.
			if ( ! $should_backup ) {
				Helper::logger()->backup()->info( sprintf( 'Not modify the original file [%s(%d)], skip the backup.', Helper::clean_file_path( $file_path ), $attachment_id ) );
				return;
			}
		}

		/**
		 * Check if exists backup file from meta,
		 * Because we will compress the original file,
		 * so we only keep the backup file if there is PNG2JPG or .bak file.
		 */
		$backup_path = $this->get_backup_file( $attachment_id, $file_path );
		if ( $backup_path ) {
			/**
			 * We will compress the original file so the backup file have to different from current file.
			 * And the backup file should be the same folder with the main file.
			 */
			if ( $backup_path !== $file_path && dirname( $file_path ) === dirname( $backup_path ) ) {
				// Check if there is a .bak file or PNG2JPG file.
				if ( strpos( $backup_path, '.bak' ) || ( Helper::get_file_ext( $backup_path, 'png' ) && Helper::get_file_ext( $file_path, 'jpg' ) ) ) {
					Helper::logger()->backup()->info( sprintf( 'Found backed up file [%s(%d)].', Helper::clean_file_path( $backup_path ), $attachment_id ) );
					return;
				}
			}
		}

		/**
		 * To avoid the conflict with 3rd party, we will generate a new backup file.
		 * Because how about if 3rd party delete the backup file before trying to restore it from Smush?
		 * We only try to use their bak file while restoring the backup file.
		 */
		$backup_path = $this->generate_unique_bak_file( $this->get_image_backup_path( $file_path ), $attachment_id );

		/**
		 * We need to save the .bak file to the meta. Because if there is a PNG, when we convert PNG2JPG,
		 * the converted file is .jpg, so the bak file will be .bak.jpg not .bak.png
		 */
		// Store the backup path in image backup sizes.
		if ( copy( $file_path, $backup_path ) ) {
			$this->add_to_image_backup_sizes( $attachment_id, $backup_path );
		} else {
			Helper::logger()->backup()->error( sprintf( 'Cannot backup file [%s(%d)].', Helper::clean_file_path( $file_path ), $attachment_id ) );
		}
	}

	/**
	 * Store new backup path for the image.
	 *
	 * @param int    $attachment_id  Attachment ID.
	 * @param string $backup_path    Backup path.
	 * @param string $backup_key     Backup key.
	 */
	public function add_to_image_backup_sizes( $attachment_id, $backup_path, $backup_key = '' ) {
		if ( empty( $attachment_id ) || empty( $backup_path ) ) {
			return;
		}

		// Get the Existing backup sizes.
		$backup_sizes = $this->get_backup_sizes( $attachment_id );
		if ( empty( $backup_sizes ) ) {
			$backup_sizes = array();
		}

		// Prevent phar deserialization vulnerability.
		if ( false !== stripos( $backup_path, 'phar://' ) ) {
			Helper::logger()->backup()->info( sprintf( 'Prevent phar deserialization vulnerability [%s(%d)].', Helper::clean_file_path( $backup_path ), $attachment_id ) );
			return;
		}

		// Return if backup file doesn't exist.
		if ( ! file_exists( $backup_path ) ) {
			Helper::logger()->backup()->notice( sprintf( 'Back file [%s(%d)] does not exist.', Helper::clean_file_path( $backup_path ), $attachment_id ) );
			return;
		}

		list( $width, $height ) = getimagesize( $backup_path );

		// Store our backup path.
		$backup_key                  = empty( $backup_key ) ? $this->backup_key : $backup_key;
		$backup_sizes[ $backup_key ] = array(
			'file'   => wp_basename( $backup_path ),
			'width'  => $width,
			'height' => $height,
		);

		wp_cache_delete( 'images_with_backups', 'wp-smush' );
		update_post_meta( $attachment_id, '_wp_attachment_backup_sizes', $backup_sizes );
	}

	/**
	 * Get backup sizes.
	 *
	 * @param int $attachment_id Attachment ID.
	 * @return mixed False or an array of backup sizes.
	 */
	public function get_backup_sizes( $attachment_id ) {
		return get_post_meta( $attachment_id, '_wp_attachment_backup_sizes', true );
	}

	/**
	 * Back up an image if it hasn't backed up yet.
	 *
	 * @since 3.9.6
	 *
	 * @param int    $attachment_id  Image id.
	 * @param string $backup_file    File path to back up.
	 *
	 * Note, we used it to manage backup PNG2JPG to keep the backup file is the original file to avoid conflicts with a duplicate PNG file.
	 * If the backup file exists it will rename the original backup file to
	 * the new backup file.
	 *
	 * @return bool  True if added this file to the backup sizes, false if the image was backed up before.
	 */
	public function maybe_backup_image( $attachment_id, $backup_file ) {
		if ( ! file_exists( $backup_file ) ) {
			return false;
		}

		// We don't use .bak file from 3rd party while backing up.
		$backed_up_file = $this->get_backup_file( $attachment_id, $backup_file );
		$was_backed_up  = true;

		if ( $backed_up_file && $backed_up_file !== $backup_file && dirname( $backed_up_file ) === dirname( $backup_file ) ) {
			$was_backed_up = rename( $backed_up_file, $backup_file );
		}

		// Backup the image.
		if ( $was_backed_up ) {
			$this->add_to_image_backup_sizes( $attachment_id, $backup_file );
		}

		return $was_backed_up;
	}

	/**
	 * Get the backup file from the meta.
	 *
	 * @since 3.9.6
	 *
	 * @param int    $id  Image ID.
	 * @param string $file_path Current file path.
	 *
	 * @return bool|null  Backup file or false|null if the image doesn't exist.
	 */
	public function get_backup_file( $id, $file_path = false ) {
		if ( empty( $id ) ) {
			return null;
		}

		if ( empty( $file_path ) ) {
			// Get unfiltered path file.
			$file_path = Helper::get_attached_file( $id, 'original' );

			// If the file path is still empty, nothing to check here.
			if ( empty( $file_path ) ) {
				return null;
			}
		}

		// Initial result.
		$backup_file = false;
		// Try to get the backup file from _wp_attachment_backup_sizes.
		$backup_sizes = $this->get_backup_sizes( $id );
		// Check if we have backup file from the metadata.
		if ( $backup_sizes ) {
			// Try to get the original file first.
			if ( isset( $backup_sizes[ $this->backup_key ]['file'] ) ) {
				$original_file = str_replace( wp_basename( $file_path ), wp_basename( $backup_sizes[ $this->backup_key ]['file'] ), $file_path );
				if ( Helper::file_exists( $original_file, $id ) ) {
					$backup_file = $original_file;
				}
			}

			// Try to check it from legacy original file or from the resized PNG file.
			if ( ! $backup_file ) {
				// If we don't have the original backup path in backup sizes, check for legacy original file path. It's for old version < V.2.7.0.
				$original_file = get_post_meta( $id, 'wp-smush-original_file', true );
				if ( ! empty( $original_file ) ) {
					// For old version < v.2.7.0, we are saving meta['file'] or _wp_attached_file.
					$original_file = Helper::original_file( $original_file );
					if ( Helper::file_exists( $original_file, $id ) ) {
						$backup_file = $original_file;
						// As we don't use this meta key so save it as a full backup file and delete the old metadata.
						WP_Smush::get_instance()->core()->mod->backup->add_to_image_backup_sizes( $id, $backup_file );
						delete_post_meta( $id, 'wp-smush-original_file' );
					}
				}

				// Check the backup file from resized PNG file.
				if ( ! $backup_file && isset( $backup_sizes['smush_png_path']['file'] ) ) {
					$original_file = str_replace( wp_basename( $file_path ), wp_basename( $backup_sizes['smush_png_path']['file'] ), $file_path );
					if ( Helper::file_exists( $original_file, $id ) ) {
						$backup_file = $original_file;
					}
				}
			}
		}

		return $backup_file;
	}

	/**
	 * Restore the image and its sizes from backup
	 *
	 * @param string $attachment_id  Attachment ID.
	 * @param bool   $resp           Send JSON response or not.
	 *
	 * @return bool
	 */
	public function restore_image( $attachment_id = '', $resp = true ) {
		// If no attachment id is provided, check $_POST variable for attachment_id.
		if ( empty( $attachment_id ) ) {
			// Check Empty fields.
			if ( empty( $_POST['attachment_id'] ) || empty( $_POST['_nonce'] ) ) {
				wp_send_json_error(
					array(
						'error_msg' => esc_html__( 'Error in processing restore action, fields empty.', 'wp-smushit' ),
					)
				);
			}

			$nonce_value   = filter_input( INPUT_POST, '_nonce', FILTER_SANITIZE_SPECIAL_CHARS );
			$attachment_id = filter_input( INPUT_POST, 'attachment_id', FILTER_SANITIZE_NUMBER_INT );

			if ( ! wp_verify_nonce( $nonce_value, "wp-smush-restore-$attachment_id" ) ) {
				wp_send_json_error(
					array(
						'error_msg' => esc_html__( 'Image not restored, nonce verification failed.', 'wp-smushit' ),
					)
				);
			}
		}

		$attachment_id = (int) $attachment_id;

		$mod = WP_Smush::get_instance()->core()->mod;

		// Set an option to avoid the smush-restore-smush loop.
		Helper::lock_file_before_doing( 'restore', $attachment_id );

		/**
		 * Delete WebP.
		 *
		 * Run WebP::delete_images always even when the module is deactivated.
		 *
		 * @since 3.8.0
		 */
		$mod->webp->delete_images( $attachment_id );

		// Restore Full size -> get other image sizes -> restore other images.
		// Get the Original Path, supported S3.
		$file_path = Helper::get_attached_file( $attachment_id, 'original' );

		// Store the restore success/failure for full size image.
		$restored = false;
		// Retrieve backup file.
		$backup_full_path = $this->get_backup_file( $attachment_id, $file_path );
		// Is restoring the PNG which is converted to JPG or not.
		$restore_png = false;

		/**
		 * Fires before restoring a file.
		 *
		 * @since 3.9.6
		 *
		 * @param string|false $backup_full_path Full backup path.
		 * @param int          $attachment_id Attachment id.
		 * @param string       $file_path Original unfiltered file path.
		 *
		 * @hooked Smush\Core\Integrations\s3::maybe_download_file()
		 */
		do_action( 'wp_smush_before_restore_backup', $backup_full_path, $attachment_id, $file_path );

		// Finally, if we have the backup path, perform the restore operation.
		if ( ! empty( $backup_full_path ) ) {
			// If the backup file is the same as the main file, we only need to re-generate the metadata.
			if ( $backup_full_path === $file_path ) {
				$restored = true;
			} else {
				// Is real backup file or .bak file.
				$is_real_filename = false === strpos( $backup_full_path, '.bak' );
				$restore_png      = Helper::get_file_ext( trim( $backup_full_path ), 'png' ) && ! Helper::get_file_ext( $file_path, 'png' );

				if ( $restore_png ) {
					// Restore PNG full size.
					$org_backup_full_path = $backup_full_path;
					if ( ! $is_real_filename ) {
						// Try to get a unique file name.
						$dirname       = dirname( $backup_full_path );
						$new_file_name = wp_unique_filename( $dirname, wp_basename( str_replace( '.bak', '', $backup_full_path ) ) );
						$new_png_file  = path_join( $dirname, $new_file_name );
						// Restore PNG full size.
						$restored = copy( $backup_full_path, $new_png_file );
						if ( $restored ) {
							// Assign the new PNG file to the backup file.
							$backup_full_path = $new_png_file;
						}
					} else {
						$restored = true;
					}

					// Restore all other image sizes.
					if ( $restored ) {
						$restored = $this->restore_png( $attachment_id, $backup_full_path, $file_path );
						if ( $restored && ! $is_real_filename ) {
							// Reset the backup file to delete it later.
							$backup_full_path = $org_backup_full_path;
						}
					}
				} else {
					// If file exists, corresponding to our backup path - restore.
					if ( ! $is_real_filename ) {
						$restored = copy( $backup_full_path, $file_path );
					} else {
						$restored = true;
					}
				}

				// Remove the backup, if we were able to restore the image.
				if ( $restored ) {
					// Remove our backup file.
					$this->remove_from_backup_sizes( $attachment_id );
					/**
					 * Delete our backup file if it's .bak file, we will try to backup later when running Smush.
					 */
					if ( ! $is_real_filename ) {
						// It will also delete file from the cloud, e.g. S3.
						Helper::delete_permanently( array( $this->backup_key => $backup_full_path ), $attachment_id, false );
					}
				}
			}
		} else {
			Helper::logger()->backup()->warning( sprintf( 'Backup file [%s(%d)] does not exist.', Helper::clean_file_path( $backup_full_path ), $attachment_id ) );
		}

		/**
		 * Regenerate thumbnails
		 *
		 * All this is handled in self::restore_png().
		 */
		if ( ! $restore_png && $restored ) {
			// Generate all other image size, and update attachment metadata.
			$metadata = wp_generate_attachment_metadata( $attachment_id, $file_path );

			// Update metadata to db if it was successfully generated.
			if ( ! empty( $metadata ) && ! is_wp_error( $metadata ) ) {
				Helper::wp_update_attachment_metadata( $attachment_id, $metadata );
			} else {
				Helper::logger()->backup()->warning( sprintf( 'Meta file [%s(%d)] is empty.', Helper::clean_file_path( $file_path ), $attachment_id ) );
			}
		}

		/**
		 * Fires before restoring a file.
		 *
		 * @since 3.9.6
		 *
		 * @param bool         $restored Restore status.
		 * @param string|false $backup_full_path Full backup path.
		 * @param int          $attachment_id Attachment id.
		 * @param string       $file_path Original unfiltered file path.
		 */
		do_action( 'wp_smush_after_restore_backup', $restored, $backup_full_path, $attachment_id, $file_path );

		// If any of the image is restored, we count it as success.
		if ( $restored ) {
			// Remove the Meta, And send json success.
			delete_post_meta( $attachment_id, Smush::$smushed_meta_key );

			// Remove PNG to JPG conversion savings.
			delete_post_meta( $attachment_id, 'wp-smush-pngjpg_savings' );

			// Remove Original File.
			delete_post_meta( $attachment_id, 'wp-smush-original_file' );

			// Delete resize savings.
			delete_post_meta( $attachment_id, 'wp-smush-resize_savings' );

			// Remove lossy flag.
			delete_post_meta( $attachment_id, 'wp-smush-lossy' );

			// Clear backups cache.
			wp_cache_delete( 'images_with_backups', 'wp-smush' );

			Core::remove_from_smushed_list( $attachment_id );

			// Get the Button html without wrapper.
			$button_html = WP_Smush::get_instance()->library()->generate_markup( $attachment_id );

			// Release the attachment after restoring.
			Helper::release_file_after_doing( 'restore', $attachment_id );

			if ( ! $resp ) {
				return true;
			}

			$size = file_exists( $file_path ) ? filesize( $file_path ) : 0;
			if ( $size > 0 ) {
				$update_size = size_format( $size ); // Used in js to update image stat.
			}

			wp_send_json_success(
				array(
					'stats'    => $button_html,
					'new_size' => isset( $update_size ) ? $update_size : 0,
				)
			);
		}

		// Release the attachment after restoring.
		Helper::release_file_after_doing( 'restore', $attachment_id );

		if ( $resp ) {
			wp_send_json_error( array( 'error_msg' => esc_html__( 'Unable to restore image', 'wp-smushit' ) ) );
		}

		return false;
	}

	/**
	 * Restore PNG.
	 *
	 * @param int    $attachment_id     Attachment ID.
	 * @param string $backup_file_path  Full backup file, the result of self::get_backup_file().
	 * @param string $file_path         File path.
	 *
	 * @return bool
	 */
	private function restore_png( $attachment_id, $backup_file_path, $file_path ) {
		if ( empty( $attachment_id ) || empty( $backup_file_path ) || empty( $file_path ) ) {
			return false;
		}

		$meta = array();

		// Else get the Attachment details.
		/**
		 * For Full Size
		 * 1. Get the original file path
		 * 2. Update the attachment metadata and all other meta details
		 * 3. Delete the JPEG
		 * 4. And we're done
		 * 5. Add an action after updating the URLs, that'd allow the users to perform an additional search, replace action
		 */
		if ( file_exists( $backup_file_path ) ) {
			$mod = WP_Smush::get_instance()->core()->mod;

			// Update the path details in meta and attached file, replace the image.
			$meta = $mod->png2jpg->update_image_path( $attachment_id, $file_path, $backup_file_path, $meta, 'full', 'restore' );

			$files_to_remove = array();
			// Unlink JPG after updating attached file.
			if ( ! empty( $meta['file'] ) && wp_basename( $backup_file_path ) === wp_basename( $meta['file'] ) ) {
				/**
				 * Note, we use size key smush-png2jpg-full for PNG2JPG file to support S3 private media,
				 * to remove converted JPG file after restoring in private folder.
				 *
				 * @see Smush\Core\Integrations\S3::get_object_key()
				 */
				$files_to_remove['smush-png2jpg-full'] = $file_path;
			}

			$jpg_meta = wp_get_attachment_metadata( $attachment_id );
			foreach ( $jpg_meta['sizes'] as $size_key => $size_data ) {
				$size_path = str_replace( wp_basename( $backup_file_path ), wp_basename( $size_data['file'] ), $backup_file_path );
				// Add to delete the thumbnails jpg.
				$files_to_remove[ $size_key ] = $size_path;
			}
			// We also try to delete this file on cloud, e.g S3.
			Helper::delete_permanently( $files_to_remove, $attachment_id, false );

			// Re-generate metadata for PNG file.
			$meta = wp_generate_attachment_metadata( $attachment_id, $backup_file_path );

			// Perform an action after the image URL is updated in post content.
			do_action( 'wp_smush_image_url_updated', $attachment_id, $file_path, $backup_file_path );
		} else {
			Helper::logger()->backup()->warning( sprintf( 'Backup file [%s(%d)] does not exist.', Helper::clean_file_path( $backup_file_path ), $attachment_id ) );
		}

		if ( ! empty( $meta ) ) {
			Helper::wp_update_attachment_metadata( $attachment_id, $meta );
			return true;
		} else {
			Helper::logger()->backup()->warning( sprintf( 'Meta file [%s(%d)] is empty.', Helper::clean_file_path( $backup_file_path ), $attachment_id ) );
		}

		return false;
	}

	/**
	 * Remove a specific backup key from the backup size array.
	 *
	 * @param int $attachment_id  Attachment ID.
	 */
	private function remove_from_backup_sizes( $attachment_id ) {
		// Get backup sizes.
		$backup_sizes = $this->get_backup_sizes( $attachment_id );

		// If we don't have any backup sizes list or if the particular key is not set, return.
		if ( empty( $backup_sizes ) || ! isset( $backup_sizes[ $this->backup_key ] ) ) {
			return;
		}

		unset( $backup_sizes[ $this->backup_key ] );

		if ( empty( $backup_sizes ) ) {
			delete_post_meta( $attachment_id, '_wp_attachment_backup_sizes' );
		} else {
			update_post_meta( $attachment_id, '_wp_attachment_backup_sizes', $backup_sizes );
		}
	}

	/**
	 * Get the attachments that can be restored.
	 *
	 * @since 3.6.0  Changed from private to public.
	 *
	 * @return array  Array of attachments IDs.
	 */
	public function get_attachments_with_backups() {
		$images = wp_cache_get( 'images_with_backups', 'wp-smush' );

		if ( ! $images ) {
			global $wpdb;
			$images = $wpdb->get_col(
				"SELECT post_id FROM {$wpdb->postmeta} WHERE meta_key='_wp_attachment_backup_sizes' AND (`meta_value` LIKE '%smush-full%' OR `meta_value` LIKE '%smush_png_path%')"
			); // Db call ok.

			if ( $images ) {
				wp_cache_set( 'images_with_backups', $images, 'wp-smush' );
			}
		}

		return $images;
	}

	/**
	 * Get the number of attachments that can be restored.
	 *
	 * @since 3.2.2
	 */
	public function get_image_count() {
		check_ajax_referer( 'smush_bulk_restore' );
		wp_send_json_success(
			array(
				'items' => $this->get_attachments_with_backups(),
			)
		);
	}

	/**
	 * Bulk restore images from the modal.
	 *
	 * @since 3.2.2
	 */
	public function restore_step() {
		check_ajax_referer( 'smush_bulk_restore' );
		$id = filter_input( INPUT_POST, 'item', FILTER_SANITIZE_NUMBER_INT, FILTER_NULL_ON_FAILURE );

		$status = $id && $this->restore_image( $id, false );

		$original_meta = wp_get_attachment_metadata( $id, true );

		// Try to get the file name from path.
		$file_name = explode( '/', $original_meta['file'] );
		$file_name = is_array( $file_name ) ? array_pop( $file_name ) : $original_meta['file'];

		wp_send_json_success(
			array(
				'success' => $status,
				'src'     => $file_name ? $file_name : __( 'Error getting file name', 'wp-smushit' ),
				'thumb'   => wp_get_attachment_image( $id ),
				'link'    => Helper::get_image_media_link( $id, $file_name, true ),
			)
		);
	}

	/**
	 * Returns the backup path for attachment
	 *
	 * @param string $attachment_path  Attachment path.
	 *
	 * @return string
	 */
	public function get_image_backup_path( $attachment_path ) {
		if ( empty( $attachment_path ) ) {
			return '';
		}

		$path = pathinfo( $attachment_path );

		if ( empty( $path['extension'] ) ) {
			return '';
		}

		return trailingslashit( $path['dirname'] ) . $path['filename'] . '.bak.' . $path['extension'];
	}

	/**
	 * Clear up all the backup files for the image while deleting the image.
	 *
	 * @since 3.9.6
	 * Note, we only call this method while deleting the image, as it will delete
	 * .bak file and might be the original file too.
	 *
	 * Note, for the old version < 3.9.6 we also save all PNG files (original file and thumbnails)
	 * when the site doesn't compress original file.
	 * But it's not safe to remove them if the user add another image with the same PNG file name, and didn't convert it.
	 * So we still leave them there.
	 *
	 * @param int $attachment_id  Attachment ID.
	 */
	public function delete_backup_files( $attachment_id ) {
		$smush_meta = get_post_meta( $attachment_id, Smush::$smushed_meta_key, true );
		if ( empty( $smush_meta ) ) {
			return;
		}

		// Save list files to remove.
		$files_to_remove = array();

		$unfiltered = false;
		$file_path  = get_attached_file( $attachment_id, false );
		// We only work with the real file path, not cloud URL like S3.
		if ( false === strpos( $file_path, ABSPATH ) ) {
			$unfiltered = true;
			$file_path  = get_attached_file( $attachment_id, true );
		}
		// Remove from the cache.
		wp_cache_delete( 'images_with_backups', 'wp-smush' );

		/**
		 * We only remove the backup file from the metadata,
		 * keep the backup file from 3rd-party.
		 */
		$backup_path  = null;// Reset backup file.
		$backup_sizes = $this->get_backup_sizes( $attachment_id );
		if ( isset( $backup_sizes[ $this->backup_key ]['file'] ) ) {
			$backup_path = str_replace( wp_basename( $file_path ), wp_basename( $backup_sizes[ $this->backup_key ]['file'] ), $file_path );
			// Add to remove the backup file.
			$files_to_remove[ $this->backup_key ] = $backup_path;
		}

		// Check the backup file from resized PNG file (< 3.9.6).
		if ( isset( $backup_sizes['smush_png_path']['file'] ) ) {
			$backup_path = str_replace( wp_basename( $file_path ), wp_basename( $backup_sizes['smush_png_path']['file'] ), $file_path );
			// Add to remove the backup file.
			$files_to_remove['smush_png_path'] = $backup_path;
		}

		if ( ! $backup_path ) {
			// Check for legacy original file path. It's for old version < V.2.7.0.
			$original_file = get_post_meta( $attachment_id, 'wp-smush-original_file', true );
			if ( ! empty( $original_file ) ) {
				// For old version < v.2.7.0, we are saving meta['file'] or _wp_attached_file.
				$backup_path = Helper::original_file( $original_file );
				// Add to remove the backup file.
				$files_to_remove[] = $backup_path;
			}
		}

		// Check meta for rest of the sizes.
		$meta = wp_get_attachment_metadata( $attachment_id, $unfiltered );
		if ( empty( $meta ) || empty( $meta['sizes'] ) ) {
			Helper::logger()->backup()->info( sprintf( 'Empty meta sizes [%s(%d)]', $file_path, $attachment_id ) );
			return;
		}

		foreach ( $meta['sizes'] as $size ) {
			if ( empty( $size['file'] ) ) {
				continue;
			}

			// Image path and backup path.
			$image_size_path   = path_join( dirname( $file_path ), $size['file'] );
			$image_backup_path = $this->get_image_backup_path( $image_size_path );

			// Add to remove the backup file.
			$files_to_remove[] = $image_backup_path;
		}

		// We also try to delete this file on cloud, e.g. S3.
		Helper::delete_permanently( $files_to_remove, $attachment_id, false );
	}

}
