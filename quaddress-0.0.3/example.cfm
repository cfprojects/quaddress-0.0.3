<cfscript>

    /*
    * VerifyService usage example
    */


    // defined somewhere on higher level
    xmlKey = "";
    maxSuggestions = 0;
    sandBox = true;

    // initialize the service
    oVerifyService = CreateObject("component", "path.to.VerifyService").init(xmlKey, maxSuggestions, sandBox);


    // address data container
    address = StructNew();
    address.street = "";
    address.street2 = "";
    address.unit = "";
    address.city = "";
    address.state = "";
    address.zip = "";
    address.lastline = "";
    address.urbanization = "";


    // here form data is collected

    if (StructKeyExists(form, "street") AND Trim(form.street) NEQ "") {
        address.street = Trim(form.street);
    }

    // ...

    // push address into the queue (repeat this to add more addresses)
    oVerifyService.addAddress(argumentcollection = address);


    // run verification process
    arrSuggestions = oVerifyService.verify();


    // response container
    response = StructNew();

    // handle errors and response
    if (oVerifyService.gotError()) {
        response.status = "fail";
        response.message = "Unexpected verification error: " & oVerifyService.getError();
    }
    else if (ArrayLen(arrSuggestions[1]) EQ 0) {
        response.status = "success";
        response.message = "No suggestions received";
    }
    else {
        response.status = "success";
        response.suggestions = arrSuggestions[1];
    }


</cfscript>

<cfdump var="#response#" label="Service response">
