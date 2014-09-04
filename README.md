# A Zabbix Dashboard
This is a dashboard for Zabbix using [Dashing](http://shopify.github.io/dashing). It is based on the work of chojayr (https://gist.github.com/chojayr/7401426).

It displays the last active triggers and a summary of all triggers.
![](https://github.com/dav3860/zabbix_dashboard/blob/master/zabbix_dashboard.jpg)

## Setup
* Make sure that Ruby 1.9+, rubygems and bundle are installed on your system.
* Download this project.
* Run bundle to install all the dependencies :
```
$ bundle
```
* Configure the necessary parameters in the job/zabbix.rb file.
* Start Dashing :
```
$ dashing start
```
* Point your browser to http://youripaddress:3030.
