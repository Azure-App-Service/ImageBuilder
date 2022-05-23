/* global ajaxurl */
/* global wp_smush_msgs */

( function( $ ) {
	'use strict';

	const s3alert = $( '#wp-smush-s3support-alert' );

	/**
	 * S3 support alert.
	 *
	 * @since 3.6.2  Moved from class-s3.php
	 */
	if ( s3alert.length ) {
		const noticeOptions = {
			type: 'warning',
			icon: 'info',
			dismiss: {
				show: true,
				label: wp_smush_msgs.noticeDismiss,
				tooltip: wp_smush_msgs.noticeDismissTooltip,
			},
		};

		window.SUI.openNotice(
			'wp-smush-s3support-alert',
			s3alert.data( 'message' ),
			noticeOptions
		);
	}

	// Dismiss S3 support alert.
	s3alert.on( 'click', 'button', () => {
		$.post( ajaxurl, { action: 'dismiss_s3support_alert' } );
	} );

	// Remove API message.
	$( '#wp-smush-api-message button.sui-button-icon' ).on( 'click', function( e ) {
		e.preventDefault();
		const notice = $( '#wp-smush-api-message' );
		notice.slideUp( 'slow', function() {
			notice.remove();
		} );
		$.post( ajaxurl, { action: 'hide_api_message' } );
	} );

	// Hide the notice after a CTA button was clicked
	function removeNotice( e ) {
		const $notice = $( e.currentTarget ).closest( '.smush-notice' );
		$notice.fadeTo( 100, 0, () =>
			$notice.slideUp( 100, () => $notice.remove() )
		);
	}

	// Only used for the Dashboard notification for now.
	$( '.smush-notice .smush-notice-act' ).on( 'click', ( e ) => {
		removeNotice( e );
	} );

	// Only used for the upgrade notice.
	$( '.smush-notice .smush-notice-dismiss' ).on( 'click', ( e ) => {
		removeNotice( e );
		$.post( ajaxurl, { action: 'dismiss_upgrade_notice' } );
	} );

	// Dismiss the update notice.
	$( '.wp-smush-update-info' ).on( 'click', '.notice-dismiss', ( e ) => {
		e.preventDefault();
		removeNotice( e );
		$.post( ajaxurl, { action: 'dismiss_update_info' } );
	} );
}( jQuery ) );
