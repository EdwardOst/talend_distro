%~d0
cd %~dp0
java -Xms256M -Xmx1024M -cp .;../lib/routines.jar;../lib/antlr-runtime-3.5.2.jar;../lib/dom4j-1.6.1.jar;../lib/log4j-1.2.16.jar;../lib/org.talend.dataquality.parser.jar;../lib/talend_file_enhanced_20070724.jar;../lib/talendcsv.jar;invoke_job2docker_0_1.jar; se_demo.invoke_job2docker_0_1.invoke_job2docker  --context=Default %* 