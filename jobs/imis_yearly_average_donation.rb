#!/usr/bin/env ruby
require 'yaml'
require 'tiny_tds'
 
yml = YAML::load(File.open('lib/db_settings.yml'))['prod_settings']

SCHEDULER.every '10h', :first_in => 300 do |job|
  client = TinyTds::Client.new(:username => yml['username'], :password => yml['password'], :host => yml['host'], :timeout => 120000)
  results = client.execute("
DECLARE @Donations TABLE
(
  ID INT NOT NULL,
  TRANSACTION_DATE DATE NOT NULL,
  AMOUNT FLOAT,
  PRIMARY KEY (ID, TRANSACTION_DATE)
)

INSERT INTO @Donations (ID, TRANSACTION_DATE, AMOUNT)
  SELECT ID, TRANSACTION_DATE, SUM(AMOUNT) 'Amount'
  FROM iMIS.dbo.Activity
  WHERE
    ACTIVITY_TYPE = 'GIFT' AND
    TRANSACTION_DATE IS NOT NULL AND
    ID IS NOT NULL AND
    ID <> 0
  GROUP BY ID, TRANSACTION_DATE

SELECT YEAR(TRANSACTION_DATE) 'Year', AVG(AMOUNT) 'Average'
FROM @Donations
GROUP BY YEAR(TRANSACTION_DATE)")
  averages = Hash.new

  results.each do |row|
    averages[row['Year']] = row['Average'].round
    #puts "Year #{row['Year']} - #{row['Average']}"
  end

  send_event('iMIS_yearly_average_donation', { current: averages[2013], last: averages[2012] })
end
