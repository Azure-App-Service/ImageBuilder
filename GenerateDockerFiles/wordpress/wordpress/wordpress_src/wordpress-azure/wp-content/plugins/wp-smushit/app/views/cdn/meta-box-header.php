<?php
/**
 * CDN meta box header.
 *
 * @package WP_Smush
 *
 * @var string $title  Title.
 */

if ( ! defined( 'WPINC' ) ) {
	die;
}

?>

<h3 class="sui-box-title">
	<?php esc_html_e( 'CDN', 'wp-smushit' ); ?>
</h3>

<div class="sui-actions-right">
    <span class="sui-field-prefix">
        <?php esc_html_e( 'How Smush CDN works?', 'wp-smushit' ); ?>
    </span>
    <span class="sui-tooltip sui-tooltip-constrained sui-tooltip-top-right" data-tooltip="<?php esc_attr_e( 'When someone visits a page on your site, the CDN will check if images are cached on the CDN. Images that are cached will be immediately served from the server closest to the user. Any image that is not yet cached will first be sent to the Smush API for optimization, then cached so the next time it is requested, the cached version will be served.', 'wp-smushit' ); ?>">
        <span class="sui-icon-info" aria-hidden="true"></span>
    </span>
</div>
