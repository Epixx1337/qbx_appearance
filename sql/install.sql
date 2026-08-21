-- Legacy table kept for compatibility: qbx_core's multichar preview and some
-- third-party resources read it directly. qbx_appearance mirrors saves into it
-- when config/server.lua `legacyMirror` is enabled.
CREATE TABLE IF NOT EXISTS `playerskins` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(255) NOT NULL,
    `model` VARCHAR(255) NOT NULL,
    `skin` TEXT NOT NULL,
    `active` TINYINT(4) NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`),
    KEY `active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `qbx_appearance` (
    `citizenid` VARCHAR(50) NOT NULL,
    `appearance` LONGTEXT NOT NULL CHECK (JSON_VALID(`appearance`)),
    `model` VARCHAR(64) NOT NULL DEFAULT 'mp_m_freemode_01',
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `qbx_appearance_outfits` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `label` VARCHAR(64) NOT NULL,
    `kind` ENUM('full', 'clothing', 'style') NOT NULL DEFAULT 'full',
    `model` VARCHAR(64) NOT NULL DEFAULT 'mp_m_freemode_01',
    `outfit` LONGTEXT NOT NULL CHECK (JSON_VALID(`outfit`)),
    `thumb` VARCHAR(255) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Shop/locker zones created in-game with /appearancezone. Loaded on resource
-- start and broadcast live on create/delete — no restart needed.
CREATE TABLE IF NOT EXISTS `qbx_appearance_zones` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `type` ENUM('clothing', 'barber', 'tattoo', 'surgeon', 'job_locker', 'gang_locker') NOT NULL,
    `label` VARCHAR(64) DEFAULT NULL,
    `group_name` VARCHAR(50) DEFAULT NULL,
    `min_grade` INT UNSIGNED NOT NULL DEFAULT 0,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `heading` DOUBLE NOT NULL DEFAULT 0,
    `width` DOUBLE NOT NULL DEFAULT 4,
    `length` DOUBLE NOT NULL DEFAULT 4,
    `height` DOUBLE NOT NULL DEFAULT 4,
    `points` LONGTEXT DEFAULT NULL, -- JSON [[x,y,z],...]: laser-drawn polygon; NULL = box zone
    `blip` TINYINT(1) NOT NULL DEFAULT 0,
    `created_by` VARCHAR(50) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Job and gang outfit presets created by bosses/leaders in the UI.
-- `group_type` disambiguates a job and a gang sharing a name.
CREATE TABLE IF NOT EXISTS `qbx_appearance_group_outfits` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `group_type` ENUM('job', 'gang') NOT NULL,
    `group_name` VARCHAR(50) NOT NULL,
    `min_grade` INT UNSIGNED NOT NULL DEFAULT 0,
    `label` VARCHAR(64) NOT NULL,
    `gender` ENUM('male', 'female', 'any') NOT NULL DEFAULT 'any',
    `model` VARCHAR(64) NOT NULL DEFAULT 'mp_m_freemode_01',
    `outfit` LONGTEXT NOT NULL CHECK (JSON_VALID(`outfit`)),
    `created_by` VARCHAR(50) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `group_lookup` (`group_type`, `group_name`, `min_grade`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
