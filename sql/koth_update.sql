-- KOTH update: all-time stats, prestige, killstreaks, reports.
-- koth-main creates these tables automatically on start (server/stats.lua);
-- this file is only needed if your database user cannot CREATE TABLE.

CREATE TABLE IF NOT EXISTS `player_stats` (
  `license` varchar(64) NOT NULL,
  `name` varchar(64) DEFAULT NULL,
  `kills` int(11) NOT NULL DEFAULT 0,
  `deaths` int(11) NOT NULL DEFAULT 0,
  `assists` int(11) NOT NULL DEFAULT 0,
  `headshots` int(11) NOT NULL DEFAULT 0,
  `matches` int(11) NOT NULL DEFAULT 0,
  `wins` int(11) NOT NULL DEFAULT 0,
  `playtime` int(11) NOT NULL DEFAULT 0,
  `best_streak` int(11) NOT NULL DEFAULT 0,
  `bounties` int(11) NOT NULL DEFAULT 0,
  `prestige` int(11) NOT NULL DEFAULT 0,
  `killstreaks` varchar(128) DEFAULT NULL,
  `created` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`license`),
  KEY `kills` (`kills`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `player_weapon_kills` (
  `license` varchar(64) NOT NULL,
  `weapon` varchar(64) NOT NULL,
  `kills` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`license`, `weapon`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `reports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `reporter_license` varchar(64) DEFAULT NULL,
  `reporter_name` varchar(64) DEFAULT NULL,
  `target_license` varchar(64) DEFAULT NULL,
  `target_name` varchar(64) DEFAULT NULL,
  `reason` varchar(32) DEFAULT NULL,
  `details` text DEFAULT NULL,
  `status` varchar(16) NOT NULL DEFAULT 'open',
  `handled_by` varchar(64) DEFAULT NULL,
  `created` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
