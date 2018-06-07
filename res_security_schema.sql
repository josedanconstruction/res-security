#Create database
CREATE DATABASE `res_security` /*!40100 DEFAULT CHARACTER SET utf8 */;

#Set as default
USE res_security;

# Create tables
#First tables with no FK
CREATE TABLE `rights` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(15) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8;

CREATE TABLE `cities` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `users` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name_UNIQUE` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=53 DEFAULT CHARSET=utf8;

#Second the ones that have PK  which are FK

CREATE TABLE `End_Points` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `route` varchar(512) NOT NULL,
  `controller` varchar(256) NOT NULL,
  `rights` int(11) NOT NULL,
  `get` tinyint(4) NOT NULL,
  `post` tinyint(4) NOT NULL,
  `put` tinyint(4) NOT NULL,
  `patch` tinyint(4) NOT NULL,
  `delete` tinyint(4) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `route_right` (`route`,`rights`),
  KEY `rights_fk_idx` (`rights`),
  CONSTRAINT `rights_fk` FOREIGN KEY (`rights`) REFERENCES `rights` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8;

CREATE TABLE `Users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `password` varchar(512) NOT NULL,
  `enabled` tinyint(4) NOT NULL DEFAULT '1',
  `city` int(11) NOT NULL,
  `role` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_unique` (`name`,`city`),
  KEY `city_user_fk_idx` (`city`),
  KEY `role_fk_idx` (`role`),
  CONSTRAINT `city_user_fk` FOREIGN KEY (`city`) REFERENCES `cities` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `role_fk` FOREIGN KEY (`role`) REFERENCES `rights` (`id`) ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=52 DEFAULT CHARSET=utf8;

#Last is the AC
CREATE TABLE `Access_Control` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `endpoint_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `city_id` int(11) NOT NULL,
  `get` tinyint(4) NOT NULL,
  `post` tinyint(4) NOT NULL,
  `put` tinyint(4) NOT NULL,
  `patch` tinyint(4) NOT NULL,
  `delete` tinyint(4) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `combined` (`endpoint_id`,`user_id`) USING BTREE,
  KEY `user_fk_idx` (`user_id`),
  KEY `city_ac_fk_idx` (`city_id`),
  CONSTRAINT `city_ac_fk` FOREIGN KEY (`city_id`) REFERENCES `cities` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `controller_fk` FOREIGN KEY (`endpoint_id`) REFERENCES `end_points` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `user_fk` FOREIGN KEY (`user_id`) REFERENCES `Users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=56 DEFAULT CHARSET=utf8;

#Insert the seed city
insert into cities(name) values('_DO_NOT_DELETE');

#Insert the seed rights
insert into rights(name) values('ALL');
insert into rights(name) values('SUPER_ADMIN');
insert into rights(name) values('USER');

#Stored Procedures

DELIMITER $$
CREATE DEFINER=`root`@`localhost` PROCEDURE `addCity`(
in name varchar(100)
)
BEGIN

DECLARE EXIT HANDLER FOR sqlexception
BEGIN
	GET DIAGNOSTICS CONDITION 1 
    @sqlstate = RETURNED_SQLSTATE, 
	@errno = MYSQL_ERRNO, 
    @text = MESSAGE_TEXT;
	SET @full_error = CONCAT("ERROR ", @errno, " (", @sqlstate, "): ", @text);
	rollback;
    signal sqlstate '45000' set message_text = @full_error;
END;

set autocommit = 0;
start transaction;
	insert into cities(name) values(name);
    set @cityId = LAST_INSERT_ID();
    select id into @all_r from rights where rights.name = 'all';
    select id into @roleId from rights where rights.name = 'super_admin';
    select users.id into @userId from users  
		inner join cities on cities.id = users.city
		where users.name = 'admin' and cities.name = '_DO_NOT_DELETE';
	insert into Access_Control (city_id, endpoint_id, user_id, Access_Control.get, post, put, patch, Access_Control.delete) 
    select  @cityId, ep.Id as endpoint_id, @userId as user_id,  ep.get, ep.post, ep.put, ep.patch, ep.delete  from end_points as ep 
		where ep.rights = @all_r; 
commit;    
END$$
DELIMITER ;

DELIMITER $$
CREATE DEFINER=`root`@`localhost` PROCEDURE `addUser`(
IN name varchar(100),
IN pwd varchar(100),
in city varchar(100),
IN role varchar(15)
)
BEGIN

DECLARE EXIT HANDLER FOR sqlexception
BEGIN
	GET DIAGNOSTICS CONDITION 1 
    @sqlstate = RETURNED_SQLSTATE, 
	@errno = MYSQL_ERRNO, 
    @text = MESSAGE_TEXT;
	SET @full_error = CONCAT("ERROR ", @errno, " (", @sqlstate, "): ", @text);
	rollback;
    signal sqlstate '45000' set message_text = @full_error;
END;

if role = 'super_admin' OR role = 'admin'  OR city = '_DO _NOT_DELETE' then
	signal sqlstate '45000' set message_text = 'fuck off';
end if;

SET autocommit = 0;

start transaction;
	UPDATE cities SET users = users +1 WHERE cities.name = city;
    set @roleId = null;
    set @cityId = null;
    set @all_r = null;
	select id into @roleId from rights where rights.name = role;
	select id into @cityId from cities where cities.name = city;
	select id into @all_r from rights where rights.name = 'all';
	insert into Users(name, password, role, city) values (name, sha2(pwd, 512), @roleId, @cityId);
    set @userId = LAST_INSERT_ID();
	insert into Access_Control (city_id, endpoint_id, user_id, Access_Control.get, post, put, patch, Access_Control.delete) 
    select  @cityId, ep.Id as endpoint_id, @userId as user_id,  ep.get, ep.post, ep.put, ep.patch, ep.delete  from end_points as ep 
		where ep.rights = @all_r OR ep.rights = @roleId; 

commit;
END$$
DELIMITER ;

DELIMITER $$
CREATE DEFINER=`root`@`localhost` PROCEDURE `comparePassword`(
IN userName varchar(100),
IN pwd varchar(100)
)
BEGIN
    declare userId int;
    
	if userName is null OR pwd is null then
		signal sqlstate '45000' set message_text = 'nulls are NOT allowed';
	end if;
	#SET @pazzword := (select password from Users where name = userName);
    select password, id into @pazzword,  @userID from Users where name = userName;
	if @pazzword is null then
		signal sqlstate '45000' set message_text = 'user does NOT exist';
	end if;
    
    if @pazzword  = sha2(pwd, 512) then
		select C.name as city, EP.route, AC.get, AC.post, AC.put, AC.patch, AC.delete from Access_Control as AC 
		inner join end_points as EP on EP.id = AC.endpoint_id
		inner join cities as C on C.id = AC.city_id
		where AC.user_id = @userID;
	end if;
END$$
DELIMITER ;



