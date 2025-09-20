-- Настройка по умолчанию, можно удалить файл, если не нужно
CREATE DATABASE IF NOT EXISTS `app` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'app'@'%' IDENTIFIED BY 'secret';
GRANT ALL PRIVILEGES ON `app`.* TO 'app'@'%';
FLUSH PRIVILEGES;