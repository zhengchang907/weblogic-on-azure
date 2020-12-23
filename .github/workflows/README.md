# Deploy web app to remote WebLogic cluster running on Azure VMs in Github workflow
## Using REST API
A simple Curl will do the work
```
curl -v \
--user #wlsUserName#:#wlsPassword# \
-H X-Requested-By:MyClient \
-H Accept:application/json \
-H Content-Type:multipart/form-data \
-F "model={
  name:    'weblogic-cafe',
  targets: [ { identity: [ 'clusters', 'cluster1' ] } ]
}" \
-F "sourcePath=@weblogic-on-azure/javaee/weblogic-cafe/target/weblogic-cafe.war" \
-X Prefer:respond-async \
-X POST http://#adminVMDNS#:7001/management/weblogic/latest/edit/appDeployments
```
When integrated with Github workflow, you'll need a few more steps before getting to the Curl:
* Steps for querying parameters needed for the Curl: weblogic server username/password, admin server dns.
* Maven build the web app.
* Call the REST API with required parameters.
## Using WebLogic Maven Plugin
The major work happens within the web app itself:
* Configure the pom.xml, add profiles, plugins, oracle maven servers like [this](https://github.com/zhengchang907/weblogic-on-azure/blob/test-workflow/javaee/weblogic-cafe/pom.xml)
* To access the oracle maven repo, you'll need to create a account for it [here](https://maven.oracle.com) 
* Then you may want to create a local maven setting files at the project scope with a configure server.
    * At the project root, create the /.mvn folder
    * Create the local setting file with sever configuration like [this](https://github.com/zhengchang907/weblogic-on-azure/blob/test-workflow/javaee/weblogic-cafe/.mvn/local-settings.xml)
    * Don't forget to make the local setting work, create a [maven.config](https://github.com/zhengchang907/weblogic-on-azure/blob/test-workflow/javaee/weblogic-cafe/.mvn/maven.config) file for it
    * Test if locally with command like:
        ```
        mvn -DskipTests -s weblogic-on-azure/javaee/weblogic-cafe/.mvn/local-settings.xml -Dmaven.wagon.httpconnectionManager.ttlSeconds=3600 clean install --file weblogic-on-azure/javaee/weblogic-cafe/pom.xml
        ```
        Before it, you'll need to enable the tunneling of WebLogic server either on the console web page, or use the REST API:
        ```
        curl -v \
        --user #wlsUserName#:#wlsPassword# \
        -H X-Requested-By:MyClient \
        -H Accept:application/json \
        -H Content-Type:application/json \
        -d "{
            tunnelingEnabled:true
        }" \
        -X POST #adminVMDNS#:7001/management/weblogic/latest/edit/servers/admin
        ```
        Because WebLogic Maven Plugin depends on a huge amount of other stuffs, add this params ```-Dmaven.wagon.httpconnectionManager.ttlSeconds=3600``` to help the connection make it through.
To integrate with Github workflow, **[action/cache](https://github.com/actions/cache)** can be leveraged to fasten the process, by caching the maven denependencies:
* Query required parameters like above
* Add caching step like below:
    ```
    - name: Cache dependencies
        id: cache-restore-dependencies
        uses: actions/cache@v2
        with:
          path: ~/.m2/repository
          key: ${{ runner.os }}-maven-${{ hashFiles('weblogic-on-azure/javaee/weblogic-cafe/pom.xml') }}-${{ hashFiles('weblogic-on-azure/javaee/weblogic-cafe/.mvn/local-settings.xml') }}
    ```
    Design the restore key based on your own needs
* Then you can add condition to skip pulling dependencies:
    ```
    - name: Maven build the web app
        id: maven-build-webapp
        if: steps.cache-restore-dependencies.outputs.cache-hit != 'true'
        run: |
          echo "build the WebLogic Cafe web app"
          echo "adminVMDNS: ${adminVMDNS}, wlsUserName: ${wlsUserName}"
          mvn -DskipTests -s weblogic-on-azure/javaee/weblogic-cafe/.mvn/local-settings.xml -Dmaven.wagon.httpconnectionManager.ttlSeconds=3600 clean install --file weblogic-on-azure/javaee/weblogic-cafe/pom.xml
    ```
## Pros and Cons
* Using REST API
    * pros
        * Focus on workflow development, fast and easy without additional background knowledge required.
        * Not much dependencies needed.
    * cons
        * The deployment is rather slow, usually takes more than 1 min.
* Using WebLogic Maven Plugin
    * pros
        * The deployment step is neat and clean.
        * The deployement is much faster after leverage caching action, and usually takes about only 15 sec.
    * cons
        * Heavy configuration for dependencies like: Oracle maven repo, http wagon, project-wide settings.
        * If the restore key changes a lot, the caching won't be able to help that much.
## Best practice
* When your workflow is running on a lower frequency or the web app changes a lot(may cause the caching doesn't help), using REST API could save some of your efforts.
* But when you focus is validating the deployment at a high frequency and a rather stable web app, it's worth it using the WebLogic Maven Plugin to save your time.
## Referrence
* [Deploy Domain-Scoped Applications using REST API(WebLogic Management Services)](https://docs.oracle.com/middleware/1221/wls/WLRUR/examples.htm#WLRUR200)
* [How to create project specific maven setting](https://stackoverflow.com/questions/43156870/create-project-specific-maven-settings)
* [How to use WebLogic Maven Plugin for deployment](https://ruleoftech.com/2014/using-the-weblogic-12c-maven-plug-in-for-deployment)
* [action/cache](https://github.com/actions/cache)
* [WebLogic HTTP Tunneling and how to enable it through console web page](http://www.garrettwinn.com/portfolio/Resources/Digital%20Harbor/Concorde/Administrator/Admin_Help/AppendixA/SSL/Enabling_HTTP_Tunneling.htm)
* [Modifying the WebLogic Server onfiguration using REST API](https://docs.oracle.com/middleware/1221/wls/WLRUR/using.htm#WLRUR148)