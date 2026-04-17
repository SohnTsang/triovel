import PowerSync

/// Local PowerSync SQLite schema mirroring the Supabase Postgres tables.
/// The `id` column is automatically included by PowerSync — never declare it.
/// Booleans are stored as INTEGER (0/1) in SQLite.
enum AppSchema {
    static let schema = Schema(
        Table(
            name: "users",
            columns: [
                .text("display_name"),
                .text("avatar_path"),
                .text("created_at"),
            ]
        ),
        Table(
            name: "trips",
            columns: [
                .text("title"),
                .text("start_date"),
                .text("end_date"),
                .text("cover_image_path"),
                .text("invite_link"),
                .text("display_timezone"),
                .text("base_currency"),
                .integer("archived"),
                .text("created_by"),
                .text("created_at"),
            ],
            indexes: [
                Index.ascending(name: "idx_trips_created_by", column: "created_by"),
            ]
        ),
        Table(
            name: "trip_members",
            columns: [
                .text("trip_id"),
                .text("user_id"),
                .text("role"),
                .text("joined_at"),
            ],
            indexes: [
                Index.ascending(name: "idx_tm_trip", column: "trip_id"),
                Index.ascending(name: "idx_tm_user", column: "user_id"),
            ]
        ),
        Table(
            name: "blocks",
            columns: [
                .text("trip_id"),
                .text("title"),
                .text("context"),
                .text("created_by"),
                .text("start_at"),
                .text("end_at"),
                .text("location_text"),
                .text("description"),
                .text("display_timezone"),
                .text("local_timezone"),
                .integer("untimed_rank"),
                .text("cover_media_id"),
                .text("created_at"),
            ],
            indexes: [
                Index.ascending(name: "idx_blocks_trip", column: "trip_id"),
                Index(name: "idx_blocks_trip_start", columns: [
                    IndexedColumn.ascending("trip_id"),
                    IndexedColumn.ascending("start_at"),
                ]),
            ]
        ),
        Table(
            name: "posts",
            columns: [
                .text("block_id"),
                .text("trip_id"),
                .text("user_id"),
                .text("body"),
                .text("visibility"),
                .text("created_at"),
            ],
            indexes: [
                Index.ascending(name: "idx_posts_block", column: "block_id"),
                Index.ascending(name: "idx_posts_user", column: "user_id"),
            ]
        ),
        Table(
            name: "post_media",
            columns: [
                .text("post_id"),
                .text("storage_path"),
                .text("media_type"),
                .text("upload_status"),
                .text("thumbnail_path"),
                .text("created_at"),
            ],
            indexes: [
                Index.ascending(name: "idx_pm_post", column: "post_id"),
            ]
        ),
        Table(
            name: "bills",
            columns: [
                .text("block_id"),
                .text("trip_id"),
                .integer("amount"),
                .text("currency"),
                .text("payer_id"),
                .text("note"),
                .text("created_at"),
            ],
            indexes: [
                Index.ascending(name: "idx_bills_trip", column: "trip_id"),
                Index.ascending(name: "idx_bills_block", column: "block_id"),
            ]
        ),
        Table(
            name: "bill_shares",
            columns: [
                .text("bill_id"),
                .text("user_id"),
                .integer("share_amount"),
                .text("trip_id"),
            ],
            indexes: [
                Index.ascending(name: "idx_bs_bill", column: "bill_id"),
                Index.ascending(name: "idx_bs_user", column: "user_id"),
            ]
        ),
        Table(
            name: "block_documents",
            columns: [
                .text("block_id"),
                .text("user_id"),
                .text("file_name"),
                .text("file_type"),
                .text("storage_path"),
                .text("upload_status"),
                .integer("file_size"),
                .text("created_at"),
            ],
            indexes: [
                Index.ascending(name: "idx_bd_block", column: "block_id"),
            ]
        ),
        Table(
            name: "payments",
            columns: [
                .text("trip_id"),
                .text("payer_id"),
                .text("receiver_id"),
                .integer("amount"),
                .text("currency"),
                .text("note"),
                .text("created_at"),
            ],
            indexes: [
                Index.ascending(name: "idx_payments_trip", column: "trip_id"),
            ]
        )
    )
}
