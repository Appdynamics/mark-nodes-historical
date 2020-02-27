# Mark Nodes Historical
Mark AppDynamics Nodes as Historical Nodes 

In a typical microservices architecture where services are designed to be transient, AppDynamics customers may notice that although a service instance or container has been destroyed, the node that represents the service in question is still visible in the AppDynamics Controller - often with a critical health status.  

The process of removing torn down nodes from AppDynamics is called 'marking nodes as historical'. By default, the Controller considers a node historical after about 20 days of inactivity and deletes the node after 30 days. When a node is marked as historical, the Controller suspends certain types of processing activities for the node, such as rule evaluation.  

AppDynamics has an inbuilt solution to instantaneously mark nodes as historical, this is done by adding `‑Dappdynamics.jvm.shutdown.mark.node.as.historical=true` to the JVM startup argument. 

The above solution does not work in some instances due to the following reasons: 

1. This will ONLY work if the instrumented application shuts down gracefully, this is seldom the case for containerised applications. 
2. The .Net agent has not implemented a similar solution
3. The minimum time the Controller can be configured to mark nodes as historical is 1 hour, this is too long in most cases as it results in false-positive alerts. The setting is called `node.retention.period` . 
4. No granularity to selectively apply the setting (in 3 above) to a set of applications or tiers. 

This project was created to resolve the stated limitations, the script runs at a pre-defined scheduled interval and mark nodes that have not reported to the controller over a pre-defined 'node availability threshold' period as historical nodes. The process runs only on a set of predefined application. 

Historical nodes are not visible in the controller, as a result, it is important to keep an audit trail of all nodes that were marked as historical by this script. The Audit log is located in the `logs` folder of the project. 

Furthermore, Whilst AppDynamics will not display a historical node, the controller will continue to retain it. If the agent starts reporting again within the time set in `node.retention.period` it will reappear in the UI and the counter will reset. The default value for `node.retention.period` is 500 hours, the minimum is 1 hour. In addition, if a node hasn't reported after the time set in `node.permanent.deletion.period`, it will be permanently deleted from the Controller. The default is 720 hours and the minimum value is 6 hours. 

## Installation 

The script was written and test in Powershell Core 6.0  - which means it can run across Linux, Windows, macOS or even as a Lambda function. 

 - How to install PowerShell Core on [Linux
   Documentation](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-6)
 - How to install PowerShell Core on [macOS
   Documentation](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-macos?view=powershell-6)  
  - How to upgrade Windows PowerShell to 5.1 [Documentation](https://docs.microsoft.com/en-us/skypeforbusiness/set-up-your-computer-for-windows-powershell/download-and-install-windows-powershell-5-1)
 - How to install PowerShell Core on Windows (if you decide to use Powershell Core on Windows instead of upgrading to Windows PowerShell 5.1) [Documentation](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-6)
 
<i>It can also be bundled into a Docker container. Please refer to the Docker container section below </i>

### Running the script 

1. Modify the config.json file properties as described in the table below: 

  | **Config Property Name** | **Description** |
  | --- | --- |
  | NodeAvailabilityThresholdInMinutes  | This threshold is used to determine nodes that are due to be marked as historical on the basis of how long a node has lost contact with the Controller |
  | ExecutionFrequencyInMinutes  | This config property controls how long the script sleeps after each execution. Use this to control the execution frequency |
  | ControllerURL  | You AppDynamics controller URL - including http/s bit |
  | OAuthToken  | Create an API Client that has an admin privilege on the target application(s). [READ MORE](https://docs.appdynamics.com/display/latest/API+Clients) |
  | ApplicationList | Define the list of target applications, comma separated: app1,app2,app3  |

2. Run the `NodeReaper.ps1` script. 

3. Check  the `logs/Aduit.log` file. The audit log should look like this: 

``````````````
2020/01/07 00:43:17 INFO Marked con-06HT8BPDCM6(845513) in appd-fix-sleeving-uat application as a historical node.
2020/01/07 00:43:17 INFO Marked WIN-5OI56V7AVUB(845524) in appd-fix-sleeving-uat application as a historical node.
2020/01/07 00:52:46 INFO Marked LIN-06HT8BPDCM6(845512) in appd-fix-sleeving-uat application as a historical node.
2020/01/07 00:52:46 INFO Marked JET-5OI56V7AVUB(845524) in appd-fix-sleeving-uat application as a historical node.
2020/01/07 00:56:37 INFO Marked io2-IL1R5UC26B0(842997) in appd-fix-sleeving-dev application as a historical node.
2020/01/07 00:56:38 INFO Marked NAO-JMJ3IPQ4E1F(843018) in appd-fix-sleeving-dev application as a historical node.
2020/01/07 00:56:38 INFO Marked RO1-2KSN12PNIC2(843099) in appd-fix-sleeving-dev application as a historical node.
2020/01/07 01:08:06 INFO Marked MYN-JMJ3IPQ4E1F(843011) in appd-sion-fix-sleeving-dev application as a historical node.
2020/01/07 01:08:06 INFO Marked ZZ1-2KSN12PNIC2(843097) in appd-fix-sleeving-dev application as a historical node.
``````````````

## Running in a Docker container 

*  To run this script in a docker container, enter the details in the config.json file as described above and run `docker-compose up` .   

The first time you run this command, you will see a lot of console output as the Docker image is built, followed by output similar to this:

````````````
mark-nodes-historical $ docker-compose up --build
Building mark-nodes-historical
Step 1/7 : FROM mcr.microsoft.com/powershell
 ---> 10749ad42dfb
Step 2/7 : RUN apt-get update &&     apt-get upgrade -y &&     apt-get clean
 ---> Using cache
 ---> 5a69f02c768b
Step 3/7 : ENV SCRIPT_HOME /opt/appdynamics/mark-node-historical
 ---> Using cache
 ---> 8aeee3ab41a3
Step 4/7 : RUN mkdir -p ${SCRIPT_HOME}
 ---> Using cache
 ---> cab2c82e4082
Step 5/7 : COPY * ${SCRIPT_HOME}/
 ---> bc9d437ae1e6
Step 6/7 : WORKDIR ${SCRIPT_HOME}
 ---> Running in 422f52bc2df9
Removing intermediate container 422f52bc2df9
 ---> d03b2a7b7353
Step 7/7 : CMD ls -ltr & pwsh ./NodeReaper.ps1
 ---> Running in e0466b469f3f
Removing intermediate container e0466b469f3f
 ---> da31e68f5ede
Successfully built da31e68f5ede
Successfully tagged appdynamics/node-reaper:latest
Recreating node-reaper ... done
Attaching to node-reaper

````````````

* To Stop the container, run:  `docker-compose stop`

* To Rebuild the container, `run docker-compose up --build`

## What is Next 

1. Add 'All application' flag. 



## Reference

1 - https://docs.appdynamics.com/display/latest/Historical+and+Disconnected+Nodes
