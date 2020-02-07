ALTER TABLE `apps_timebill`.`LuPeople` 
DROP COLUMN `Salt`,
DROP COLUMN `Password`,
CHANGE COLUMN `PasswordHash` `PasswordHash` VARCHAR(200) NULL DEFAULT NULL ;

ALTER TABLE `apps_timebill`.`fTime`
CHANGE COLUMN `UseOTRate` `UseOTRate` TINYINT(1) NOT NULL DEFAULT '0' ,
CHANGE COLUMN `PreDeliveryFlag` `PreDeliveryFlag` TINYINT(1) NOT NULL DEFAULT '0' ,
CHANGE COLUMN `DoNotBillFlag` `DoNotBillFlag` TINYINT(1) NOT NULL DEFAULT '0' ;


UPDATE `apps_timebill`.`LuPeople` SET `BillsTime` = '0' WHERE (`PersonID` = '3')
UPDATE `apps_timebill`.`LuPeople` SET `BillsTime` = '0' WHERE (`PersonID` = '3')
UPDATE `apps_timebill`.`LuPeople` SET `BillsTime` = '0' WHERE (`PersonID` = '4')
UPDATE `apps_timebill`.`LuPeople` SET `ActiveUser` = '0', `BillsTime` = '0' WHERE (`PersonID` = '5')
UPDATE `apps_timebill`.`LuPeople` SET `ActiveUser` = '0', `BillsTime` = '0' WHERE (`PersonID` = '69')
UPDATE `apps_timebill`.`LuPeople` SET `ActiveUser` = '0', `BillsTime` = '0' WHERE (`PersonID` = '72')
UPDATE `apps_timebill`.`LuPeople` SET `ActiveUser` = '0', `BillsTime` = '0' WHERE (`PersonID` = '73')
UPDATE `apps_timebill`.`LuPeople` SET `ActiveUser` = '0', `BillsTime` = '0' WHERE (`PersonID` = '75')
UPDATE `apps_timebill`.`LuPeople` SET `ActiveUser` = '0', `BillsTime` = '0' WHERE (`PersonID` = '76')
