ALTER TABLE `apps_timebill`.`LuPeople` 
DROP COLUMN `Salt`,
DROP COLUMN `Password`,
CHANGE COLUMN `PasswordHash` `PasswordHash` VARCHAR(200) NULL DEFAULT NULL ;

ALTER TABLE `apps_timebill`.`fTime`
CHANGE COLUMN `UseOTRate` `UseOTRate` TINYINT(1) NOT NULL DEFAULT '0' ,
CHANGE COLUMN `PreDeliveryFlag` `PreDeliveryFlag` TINYINT(1) NOT NULL DEFAULT '0' ,
CHANGE COLUMN `DoNotBillFlag` `DoNotBillFlag` TINYINT(1) NOT NULL DEFAULT '0' ;
