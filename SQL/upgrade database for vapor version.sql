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

ALTER TABLE `apps_timebill`.`fProjects`
DROP COLUMN `IsBillPassedOn`;

ALTER TABLE `apps_timebill`.`RefProjectEventsReportable`
ADD COLUMN `SortOrder` SMALLINT(6) NULL AFTER `EventWhoGenerates`;

UPDATE `apps_timebill`.`RefProjectEventsReportable` SET `SortOrder` = '1' WHERE (`EventID` = '1');
UPDATE `apps_timebill`.`RefProjectEventsReportable` SET `SortOrder` = '2' WHERE (`EventID` = '2');
UPDATE `apps_timebill`.`RefProjectEventsReportable` SET `SortOrder` = '3' WHERE (`EventID` = '3');
UPDATE `apps_timebill`.`RefProjectEventsReportable` SET `SortOrder` = '4' WHERE (`EventID` = '4');
UPDATE `apps_timebill`.`RefProjectEventsReportable` SET `SortOrder` = '5' WHERE (`EventID` = '5');
UPDATE `apps_timebill`.`RefProjectEventsReportable` SET `SortOrder` = '6' WHERE (`EventID` = '9');
UPDATE `apps_timebill`.`RefProjectEventsReportable` SET `SortOrder` = '7' WHERE (`EventID` = '6');
UPDATE `apps_timebill`.`RefProjectEventsReportable` SET `SortOrder` = '8' WHERE (`EventID` = '7');
UPDATE `apps_timebill`.`RefProjectEventsReportable` SET `SortOrder` = '9' WHERE (`EventID` = '8');
UPDATE `apps_timebill`.`RefProjectEventsReportable` SET `SortOrder` = '10' WHERE (`EventID` = '10');
UPDATE `apps_timebill`.`RefProjectEventsReportable` SET `SortOrder` = '11' WHERE (`EventID` = '23');
UPDATE `apps_timebill`.`RefProjectEventsReportable` SET `SortOrder` = '12' WHERE (`EventID` = '24');
UPDATE `apps_timebill`.`RefProjectEventsReportable` SET `SortOrder` = '13' WHERE (`EventID` = '15');
UPDATE `apps_timebill`.`RefProjectEventsReportable` SET `SortOrder` = '14' WHERE (`EventID` = '16');
UPDATE `apps_timebill`.`RefProjectEventsReportable` SET `SortOrder` = '15' WHERE (`EventID` = '17');
UPDATE `apps_timebill`.`RefProjectEventsReportable` SET `SortOrder` = '16' WHERE (`EventID` = '12');
UPDATE `apps_timebill`.`RefProjectEventsReportable` SET `SortOrder` = '17' WHERE (`EventID` = '13');
UPDATE `apps_timebill`.`RefProjectEventsReportable` SET `SortOrder` = '18' WHERE (`EventID` = '14');
