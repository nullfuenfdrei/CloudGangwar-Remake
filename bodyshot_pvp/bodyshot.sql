-- =======================================================================
--  BODYSHOT GANGWAR – Datenbank (MySQL 5.7+ / MariaDB 10.3+)
--
--  Import: in HeidiSQL / phpMyAdmin / DBeaver deine Datenbank auswählen
--  und diese Datei ausführen ("SQL-Datei laden" bzw. "Importieren").
--  Die Tabellen werden beim Serverstart auch automatisch angelegt,
--  falls sie fehlen – der Import schadet aber nie (IF NOT EXISTS).
--
--  Alte Daten (Resource-KVP aus v3) werden beim ersten Start mit leerer
--  Datenbank automatisch übernommen.
-- =======================================================================

-- Accounts: eine Zeile pro Spieler. Geld, XP, Premium und Name darfst du
-- hier ändern – aber nur, solange der Server AUS ist (sonst überschreibt
-- der Server deine Änderung beim nächsten Speichern).
CREATE TABLE IF NOT EXISTS `bs_accounts` (
  `id`           INT UNSIGNED NOT NULL,
  `license`      VARCHAR(64)  NOT NULL,
  `name`         VARCHAR(32)  NOT NULL,
  `money`        INT          NOT NULL DEFAULT 0,
  `xp`           INT          NOT NULL DEFAULT 0,
  `premium`      TINYINT(1)   NOT NULL DEFAULT 0,
  `kills`        INT          NOT NULL DEFAULT 0,
  `deaths`       INT          NOT NULL DEFAULT 0,
  `best_streak`  INT          NOT NULL DEFAULT 0,
  `gw_wins`      INT          NOT NULL DEFAULT 0,
  `duel_wins`    INT          NOT NULL DEFAULT 0,
  `duel_losses`  INT          NOT NULL DEFAULT 0,
  `login_streak` INT          NOT NULL DEFAULT 0,
  `play_seconds` INT          NOT NULL DEFAULT 0,
  `created_at`   INT          NOT NULL DEFAULT 0,
  `last_login`   INT          NOT NULL DEFAULT 0,
  `data`         LONGTEXT     NOT NULL,
  `updated_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_license` (`license`),
  UNIQUE KEY `uq_name` (`name`),
  KEY `ix_kills` (`kills`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Private Teams
CREATE TABLE IF NOT EXISTS `bs_teams` (
  `id`         INT UNSIGNED NOT NULL,
  `name`       VARCHAR(32)  NOT NULL,
  `tag`        VARCHAR(8)   NOT NULL,
  `color`      VARCHAR(9)   NOT NULL DEFAULT '#2f80ff',
  `leader`     INT          NOT NULL DEFAULT 0,
  `members`    INT          NOT NULL DEFAULT 0,
  `data`       LONGTEXT     NOT NULL,
  `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Gangwar-Gebiete: Besitzer ('' = neutral) und Abklingzeit
CREATE TABLE IF NOT EXISTS `bs_zones` (
  `zone_key`       VARCHAR(48) NOT NULL,
  `owner`          VARCHAR(48) NOT NULL DEFAULT '',
  `cooldown_until` INT         NOT NULL DEFAULT 0,
  `updated_at`     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`zone_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Hood-Positionen, die im Spiel mit /sethood verschoben wurden
CREATE TABLE IF NOT EXISTS `bs_hoods` (
  `team_key`   VARCHAR(48) NOT NULL,
  `data`       LONGTEXT    NOT NULL,
  `updated_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`team_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Banns (until_ts = 0 heißt für immer)
CREATE TABLE IF NOT EXISTS `bs_bans` (
  `license`    VARCHAR(64)  NOT NULL,
  `account_id` INT          NOT NULL DEFAULT -1,
  `name`       VARCHAR(64)  NOT NULL DEFAULT '',
  `reason`     VARCHAR(255) NOT NULL DEFAULT '',
  `banned_by`  VARCHAR(64)  NOT NULL DEFAULT '',
  `until_ts`   INT          NOT NULL DEFAULT 0,
  `created_ts` INT          NOT NULL DEFAULT 0,
  PRIMARY KEY (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Kopfgelder (eins pro Spieler, Beträge stapeln sich)
CREATE TABLE IF NOT EXISTS `bs_bounties` (
  `target_id`  INT       NOT NULL,
  `amount`     INT       NOT NULL DEFAULT 0,
  `data`       LONGTEXT  NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Fortlaufende Nummern (User-IDs ab 0, Team-IDs)
CREATE TABLE IF NOT EXISTS `bs_counters` (
  `name`  VARCHAR(32) NOT NULL,
  `value` INT         NOT NULL DEFAULT 0,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Sonstige Daten des Servers
CREATE TABLE IF NOT EXISTS `bs_kv` (
  `k`          VARCHAR(128) NOT NULL,
  `v`          LONGTEXT     NOT NULL,
  `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`k`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Protokoll: wer hat welchen Skin aus welcher Case gezogen
CREATE TABLE IF NOT EXISTS `bs_case_log` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `account_id` INT          NOT NULL,
  `case_key`   VARCHAR(32)  NOT NULL,
  `skin_key`   VARCHAR(64)  NOT NULL,
  `rarity`     VARCHAR(16)  NOT NULL,
  `duplicate`  TINYINT(1)   NOT NULL DEFAULT 0,
  `created_at` INT          NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `ix_case_account` (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Protokoll: 1v1-Duelle
CREATE TABLE IF NOT EXISTS `bs_duel_log` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `winner_id`  INT          NOT NULL,
  `loser_id`   INT          NOT NULL,
  `score`      VARCHAR(8)   NOT NULL DEFAULT '',
  `stake`      INT          NOT NULL DEFAULT 0,
  `weapon`     VARCHAR(48)  NOT NULL DEFAULT '',
  `arena`      VARCHAR(48)  NOT NULL DEFAULT '',
  `reason`     VARCHAR(16)  NOT NULL DEFAULT '',
  `created_at` INT          NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `ix_duel_winner` (`winner_id`),
  KEY `ix_duel_loser` (`loser_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Protokoll: eingelöste Kopfgelder
CREATE TABLE IF NOT EXISTS `bs_bounty_log` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `target_id`  INT          NOT NULL,
  `hunter_id`  INT          NOT NULL,
  `amount`     INT          NOT NULL DEFAULT 0,
  `created_at` INT          NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `ix_bounty_hunter` (`hunter_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
