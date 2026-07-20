CREATE TABLE IF NOT EXISTS `paradise_storages` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `stash_id` VARCHAR(100) UNIQUE NOT NULL,
    `label` VARCHAR(255) NOT NULL,
    `slots` INT NOT NULL DEFAULT 50,
    `weight` INT NOT NULL DEFAULT 100000,
    `coords` TEXT NOT NULL,
    `stash_type` VARCHAR(50) NOT NULL,
    `job` VARCHAR(50) DEFAULT NULL,
    `gang` VARCHAR(50) DEFAULT NULL,
    `cid` VARCHAR(50) DEFAULT NULL,
    `passcode` VARCHAR(50) DEFAULT NULL,
    `required_item` VARCHAR(100) DEFAULT NULL,
    `stash_mode` VARCHAR(20) DEFAULT 'shared',
    `show_blip` BOOLEAN DEFAULT FALSE,
    `blip_sprite` INT DEFAULT 478,
    `blip_color` INT DEFAULT 2,
    `blip_scale` FLOAT DEFAULT 0.8,
    `spawn_prop` BOOLEAN DEFAULT FALSE,
    `prop_model` VARCHAR(255) DEFAULT NULL,
    `created_by` VARCHAR(50) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- MIGRATIONS FOR EXISTING INSTALLATIONS
-- Only run these if you created the table on an older version.
-- NOTE: These run automatically on resource start, so manual
-- execution is normally NOT needed. If a query errors with
-- "Duplicate column name", the column already exists - skip it.
-- ============================================================

-- Migration 1: add required_item column
-- ALTER TABLE `paradise_storages` ADD COLUMN `required_item` VARCHAR(100) DEFAULT NULL AFTER `passcode`;

-- Migration 2: add stash_mode column (personal/shared for job & gang stashes)
-- ALTER TABLE `paradise_storages` ADD COLUMN `stash_mode` VARCHAR(20) DEFAULT 'shared' AFTER `required_item`;
-- UPDATE `paradise_storages` SET `stash_mode` = 'shared' WHERE `stash_mode` IS NULL AND (`stash_type` = 'job' OR `stash_type` = 'gang');
