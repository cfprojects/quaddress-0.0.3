<!---

VerifyService - Qualified Address API Toolkit


This library implements communication with the Address Entry Pro web
service to verify addresses. Library was created using ColdFusion 8.

More information about the service can be found here
http://www.qualifiedaddress.com/Products/LiveAddress-API/


Author: S.Galashyn <s.galashyn@ziost.com>
Created: 07/03/2009
Changed: 12/12/2009
Version: 0.0.3


To set the library up to work with your account, you'll need to get the unique
XML access key found at https://www.qualifiedAddress.com/Account/Api/Install/XML/.

By default the web service will return only one suggestion per address. If you
want to have more than one suggestion be returned, then pass max_suggestions
argument into the init method. Maximum allowed value is 10.


Requirements
Library was created using Adobe ColdFusion 8, should be compatible with Adobe ColdFusion 9.
Railo 3.1 is not supported yet.
Other application servers are not tested.


--->
<cfcomponent displayname="VerifyService" output="false" hint="Qualified Address API Toolkit">

<cfscript>

    this.lockName = CreateUUID();

    // WSDL URL
    variables.wsdl = "https://api.qualifiedaddress.com/Address/v1/VerifyService.asmx?WSDL";

    // XML API access key
    variables.xmlKey = "";

    // max number of suggestions to return
    // note: set zero to return default number
    variables.maxSuggestions = 0;

    // demo mode flag
    // true = The address will not be cleaned.
    // false = The address will be cleaned.
    // note: this can be used in testing situations.
    variables.sandBox = false;

    // VO components path
    variables.voPath = "";

    // addresses to check container
    variables.addresses = "";

    // error containers
    variables.errorStatus = false;
    variables.errorText = "";

</cfscript>


<!--- INITIALIZATION --->


<cffunction name="init" access="public" output="false" hint="Component initialization">
    <cfargument name="xml_key" type="string" required="true" hint="XML API access key">
    <cfargument name="max_suggestions" type="numeric" required="false" default="0" hint="Max number of suggestions">
    <cfargument name="sandbox" type="string" required="false" default="false" hint="Demo mode flag">
    <cfargument name="vo_path" type="string" required="false" default="vo/" hint="Demo mode flag">
    <cfscript>

        // set up preferences
        variables.xmlKey = arguments.xml_key;
        variables.maxSuggestions = arguments.max_suggestions;
        variables.sandBox = arguments.sandbox;
        variables.voPath = arguments.vo_path;

        // init addresses container
        variables.addresses = CreateObject("component", variables.voPath & "Addresses");
        variables.addresses.AddressRequest = ArrayNew(1);

        return this;

    </cfscript>
</cffunction>


<cffunction name="addAddress" access="public" returntype="any" output="false" hint="Add address to the verification queue">
    <cfargument name="street" type="string" required="true" hint="First address line">
    <cfargument name="street2" type="string" required="false" default="" hint="">
    <cfargument name="unit" type="string" required="false" default="" hint="">
    <cfargument name="city" type="string" required="true" hint="">
    <cfargument name="state" type="string" required="true" hint="">
    <cfargument name="zip" type="string" required="true" hint="">
    <cfargument name="lastline" type="string" required="false" default="" hint="">
    <cfargument name="urbanization" type="string" required="false" default="" hint="">
    <cfset var address = "" />
    <cfscript>

        try {

            // build the request
            address = CreateObject("component", variables.voPath & "AddressRequest");
            address.Street = arguments.street;
            address.Street2 = arguments.street2;
            address.UnitNumber = arguments.unit;
            address.City = arguments.city;
            address.State = arguments.state;
            address.ZipCode = arguments.zip;
            address.LastLine = arguments.lastline;
            address.Urbanization = arguments.urbanization;


            // push to verification queue
            ArrayAppend(variables.addresses.AddressRequest, address);


            return variables.addresses.AddressRequest;

        }
        catch (Any exception) {
            return variables.error("[addAddress] " & exception.message, exception.detail);
        }

    </cfscript>
</cffunction>


<!--- VERIFICATION --->


<cffunction name="verify" access="public" returntype="any" output="false" hint="Run verification process">
    <cfscript>

        var loc = StructNew();

        // results container
        loc.arrSuggestions = ArrayNew(1);


        try {


            // check if any addresses to check provided
            if (ArrayLen(variables.addresses.AddressRequest) EQ 0) {
                return variables.error("Verification failed: no addresses provided");
            }


            // initialize web-service object
            loc.service = CreateObject("webservice", variables.wsdl);


            // initialize request object
            loc.loc.serviceRequest = CreateObject("component", variables.voPath & "ServiceRequest");
            loc.serviceRequest.Addresses = variables.addresses;
            loc.serviceRequest.Key = variables.xmlKey;
            loc.serviceRequest.Suggestions = variables.maxSuggestions;
            loc.serviceRequest.SandBox = variables.sandBox;


            // try to invoke the service
            loc.tmpResponseObject = loc.service.Execute(loc.serviceRequest);

            if (NOT isObject(loc.tmpResponseObject)) {
                return variables.error("Verification failed: invalid response received");
            }


            // initialize response containers object
            loc.serviceResponse = CreateObject("component", variables.voPath & "ServiceResponse");


            // grab response attributes

            loc.serviceResponse.Success = loc.tmpResponseObject.isSuccess();
            if (NOT isDefined("loc.serviceResponse.Success")) {
                loc.serviceResponse.Success = "No";
            }

            loc.serviceResponse.Message = loc.tmpResponseObject.getMessage();
            if (NOT isDefined("loc.serviceResponse.Message")) {
                loc.serviceResponse.Message = "";
            }

            if (NOT loc.serviceResponse.Success) {
                return variables.error("Verification failed: service returned error status", loc.serviceResponse.Message);
            }

            loc.serviceResponse.Addresses = loc.tmpResponseObject.getAddresses().getArrayOfAddressResponse();
            if (NOT isDefined("loc.serviceResponse.Addresses")) {
                loc.serviceResponse.Addresses = ArrayNew(1);
            }


            // grab suggestions for each address

            loc.addCount = ArrayLen(loc.serviceResponse.Addresses);

            for (loc.ad=1; loc.ad LTE loc.addCount; loc.ad++) {

                loc.arrAddressesIn = loc.serviceResponse.Addresses[loc.ad].getAddressResponse();

                loc.arrAddressesOut = ArrayNew(1);

                // use isDefined to catch the "undefined" values can be returned on some errors
                if (isDefined("loc.arrAddressesIn") AND isArray(loc.arrAddressesIn)) {

                    for (loc.sg=1; loc.sg LTE ArrayLen(loc.arrAddressesIn); loc.sg++) {

                        // verify the suggestion
                        if (NOT isObject(loc.arrAddressesIn[loc.sg])) {
                            continue;
                        }

                        // build single suggestion
                        suggestion = StructNew();
                        suggestion["id"] = loc.arrAddressesIn[loc.sg].getId();
                        suggestion["addressee"] = loc.arrAddressesIn[loc.sg].getAddressee();
                        suggestion["street"] = loc.arrAddressesIn[loc.sg].getStreet();
                        suggestion["street2"] = loc.arrAddressesIn[loc.sg].getStreet2();
                        suggestion["unit"] = loc.arrAddressesIn[loc.sg].getUnitNumber();
                        suggestion["city"] = loc.arrAddressesIn[loc.sg].getCity();
                        suggestion["state"] = loc.arrAddressesIn[loc.sg].getState();
                        suggestion["zip"] = loc.arrAddressesIn[loc.sg].getZipCode();
                        suggestion["lastLine"] = loc.arrAddressesIn[loc.sg].getLastLine();
                        suggestion["urbanization"] = loc.arrAddressesIn[loc.sg].getUrbanization();

                        ArrayAppend(loc.arrAddressesOut, suggestion);

                    }

                }

                ArrayAppend(loc.arrSuggestions, loc.arrAddressesOut);

            }


        }
        catch (Any exception) {
            return variables.error("[verify] " & exception.message, exception.detail);
        }

        return loc.arrSuggestions;

    </cfscript>
</cffunction>


<!--- DEBUGGING --->

<cffunction name="getAddresses" access="public" output="false" returntype="any" hint="Returns verification queue">
    <cfreturn variables.addresses.AddressRequest />
</cffunction>



<!--- COMPONENT STATUS --->


<cffunction name="error" access="private" output="false" returntype="boolean" hint="Throws component error">
    <cfargument name="message" type="string" required="true" hint="Error message">
    <cfargument name="detail" type="string" required="false" default="" hint="Error detail">

    <cfset variables.errorText = arguments.message />

    <cfif arguments.detail NEQ "">
        <cfset variables.errorText = variables.errorText & " [" & arguments.detail & "]" />
    </cfif>

    <cfset variables.errorStatus = true />

    <cfreturn false />

</cffunction>


<cffunction name="gotError" access="public" output="false" returntype="boolean" hint="Returns error flag status">
    <cfreturn variables.errorStatus />
</cffunction>


<cffunction name="getError" access="public" output="false" returntype="string" hint="Returns last error text">
    <cfset variables.errorStatus = false />
    <cfreturn variables.errorText />
</cffunction>


</cfcomponent>