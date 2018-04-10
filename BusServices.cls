//Client: Bob
//Author: Ram Dafe
//Title: RTS Royal Star Bus Sevices
public with sharing class BusServices {
    public static String COMA =',';
    public static final String INVALID_POSTALCODE_MSG = 'Enter a valid postal code';
    @TestVisible String GOOGLE_APIKEY = 'AIzaSyD-3pHvgF6lLibxWFCYfAG5e6QGEn7cmaE';

    public String selectedSchoolOption                                              {get; set;}
    public String postalCode                                                        {get; set;}
    public String billingStreet                                                     {get; set;}
    public String accountFirstName                                                  {get; set;}
    public String accountLastName                                                   {get; set;}
    public String selectedRoute                                                     {get; set;}
    //public String mapResponseBody                                                   {get; set;}

    public Integer ticketsCount                                                     {get; set;}
    //public Integer rowToRemove                                                      {get; set;}

    public Boolean showCheckBusesResults                                            {get; set;}
    public Boolean hasConfirmedBooking                                              {get; set;}
    public Boolean hasVehicleInformation                                            {get; set;}
    public Boolean showPageBlockToEnterPostalCodeAndSelectSchool                    {get; set;}
    //public Boolean shouldDisplayMap                                                 {get; set;}
    public Boolean renderSeatsNotAvailablePage                                      {get; set;}
    public Boolean gotoPreviouscheckAvailableRoutesBool                             {get; set;}


    public List<Stop_Route_Vehicle_Jn__c> stpRouteVehicleList                        {get; set;}
    public List<Contact> childrenList                                                {get; set;}
    public List<SelectOption> routeOptions                                           {get; set;}

    public Account accObj                                                            {get; set;}

    public BusServices() {
        ticketsCount = 1;
        showCheckBusesResults = false;
        hasVehicleInformation = false;
        showPageBlockToEnterPostalCodeAndSelectSchool = true;
        // shouldDisplayMap = false;
        renderSeatsNotAvailablePage = false;
        hasConfirmedBooking = false;
        gotoPreviouscheckAvailableRoutesBool = true;
        childrenList = new List<Contact>();
        // newChildrenList = new List<Contact>();
        // Contact childContactObj = new Contact();
        // childrenList.add(childContactObj);
        accObj = new Account();
    }

    public List<SelectOption> schoolOptions{
        get {
            List<SelectOption> options = new List<SelectOption>();
            options.add(new selectoption('', 'SELECT SCHOOL'));
            for(Stop__c schoolstop : [
                select ID
                     , Name
                  FROM Stop__c
                 WHERE IsSchool__c = true //#TODO Change logic here
            ]) {
                options.add(new SelectOption(schoolStop.Id, schoolStop.Name));
            }

            return options;
        } set;
    }

    public void checkAvailableRoutes() {
        System.debug('method running...checkAvailableRoutes...');
        // if(true == String.isBlank(postalCode)
        //  || false == postalCode.isNumeric()
        //  || null == selectedSchoolOption
        //  || postalCode.length() < 6 ) {
        //      return;
        // }

        Map<String, Object> postalCodeLocationMap = fetchLatLngForPostalCode();
        System.debug('lat lng for the given postal code: ==> ' + postalCodeLocationMap);

        if(null == postalCodeLocationMap) {
            return;
        }

        Location postalCodeLocation = Location.newInstance((Decimal) postalCodeLocationMap.get('lat'), (Decimal) postalCodeLocationMap.get('lng'));
        System.debug('loc:==> ' + postalCodeLocation);

        Map<String, Decimal> stopNameAndRespectiveDistanceFromPostalCodeLocationMap = fetchStopNameAndDistanceFromPostalCodeLocationMap(postalCodeLocation);

        Map<String, Decimal> stopNameAndRespectiveDistanceFromPostalCodeLocationSortedMap = fetchStopNameAndDistanceFromPostalCodeLocationSortedMap(stopNameAndRespectiveDistanceFromPostalCodeLocationMap);

        routeOptions = fetchRouteOptions(stopNameAndRespectiveDistanceFromPostalCodeLocationSortedMap);
        System.debug('routeOptions::@newRamDa: ==> ' + routeOptions);
        if(null == routeOptions || true == routeOptions.isEmpty()) {
            return;
        }

        showCheckBusesResults = true;
        showPageBlockToEnterPostalCodeAndSelectSchool = false;
        hasVehicleInformation = false;
        renderSeatsNotAvailablePage = false;
    }

    public List<SelectOption> fetchRouteOptions(Map<String, Decimal> stopNameAndRespectiveDistanceFromPostalCodeLocationSortedMap) {
        if( null == selectedSchoolOption
         && null == stopNameAndRespectiveDistanceFromPostalCodeLocationSortedMap) {
            return new List<SelectOption>();
        }
        routeOptions = new List<SelectOption>();


        routeOptions.add(new SelectOption('','SELECT ROUTE'));

        List<Stop_Route_Junction__c> stop_Route_JunctionList =  [
            SELECT  Id
                 ,  BusStop__r.Name
                 ,  BusRoute__r.Name
                 ,  BusRoute__r.Destination__r.Name
                 ,  Sort_Order__c
              FROM  Stop_Route_Junction__c
             WHERE  BusRoute__r.Destination__r.Id =: selectedSchoolOption
               AND  BusStop__r.Name IN: stopNameAndRespectiveDistanceFromPostalCodeLocationSortedMap.keySet()
          ORDER BY  Sort_Order__c
          ];

        System.debug('this is@ramda..srJN: ' + stop_Route_JunctionList);
        System.debug('this is @ramda..maploc: ' + stopNameAndRespectiveDistanceFromPostalCodeLocationSortedMap);
        if(true == stop_Route_JunctionList.isEmpty()) {
            return new List<SelectOption>();
        }
        Set<String> stopSet = new Set<String>();
        for(Stop_Route_Junction__c stopRtJnObj : stop_Route_JunctionList) {
            System.debug('@@BusRoute__r.Destination__r.Name:==>' + stopRtJnObj.BusRoute__r.Destination__r.Name);
            routeOptions.add(
                    new SelectOption(
                          stopRtJnObj.Id
                        , stopRtJnObj.BusRoute__r.Name
                        + ' ' + stopRtJnObj.Sort_Order__c
                        + ' (' + stopNameAndRespectiveDistanceFromPostalCodeLocationSortedMap.get(
                            stopRtJnObj.BusStop__r.Name
                        )
                        + ' km away '
                        + stopRtJnObj.BusStop__r.Name +  ')'
                    )
                );
        }

    return routeOptions;
}

    public Map<String, Decimal> fetchStopNameAndDistanceFromPostalCodeLocationMap (Location postalCodeLocation) {
        Map<String, Decimal> stopNameAndRespectiveDistanceFromPostalCodeLocationMap;

        if(null == postalCodeLocation) {
            return stopNameAndRespectiveDistanceFromPostalCodeLocationMap;
        }

        stopNameAndRespectiveDistanceFromPostalCodeLocationMap = new Map<String, Decimal>();
        for(Stop__c busStop : [
            SELECT Id
                 , Name
                 , Stop_Location__c
              FROM Stop__c
             WHERE IsSchool__c = false// Change here
         ]) {
               Decimal busStopDistanceFromPostalCodeLocation = (Decimal) Location.getDistance(postalCodeLocation, busStop.Stop_Location__c, 'km');
               stopNameAndRespectiveDistanceFromPostalCodeLocationMap.put(
                      busStop.Name
                    , NewCreative_TestUtility_Class.roundNumberToDesiredDecimalPlaces (
                        busStopDistanceFromPostalCodeLocation, 2
                      )
                );
            }
            System.debug('Location map:===>@ramda..' + stopNameAndRespectiveDistanceFromPostalCodeLocationMap);
        return stopNameAndRespectiveDistanceFromPostalCodeLocationMap;
    }

    public Map<String, Decimal> fetchStopNameAndDistanceFromPostalCodeLocationSortedMap( Map<String, Decimal> stopNameAndRespectiveDistanceFromPostalCodeLocationMap ) {

        Map<String, Decimal> stopNameAndRespectiveDistanceFromPostalCodeLocationSortedMap = new Map<String, Decimal>();

        if(null == stopNameAndRespectiveDistanceFromPostalCodeLocationMap) {
            return stopNameAndRespectiveDistanceFromPostalCodeLocationSortedMap;
        }

        List<Decimal> distancesList = fetchDistancesList(
            stopNameAndRespectiveDistanceFromPostalCodeLocationMap
        );

        Integer numberOfMapKeys = 1;
        for(Decimal dis : distancesList) {
            for(String busStop : stopNameAndRespectiveDistanceFromPostalCodeLocationMap.keySet()) {
                 if( numberOfMapKeys <= 3
                  && stopNameAndRespectiveDistanceFromPostalCodeLocationMap.get(busStop) == dis) {
                         stopNameAndRespectiveDistanceFromPostalCodeLocationSortedMap.put(busStop, dis);
                         numberOfMapKeys++;
                     }
             }

        }

        return stopNameAndRespectiveDistanceFromPostalCodeLocationSortedMap;
    }

    public List<Decimal> fetchDistancesList(Map<String, Decimal> stopNameAndRespectiveDistanceFromPostalCodeLocationMap ) {
        List<Decimal> distancesList = new List<Decimal>();

        if(null == stopNameAndRespectiveDistanceFromPostalCodeLocationMap) {
            return distancesList;
        }
        for(String busStopKey : stopNameAndRespectiveDistanceFromPostalCodeLocationMap.keySet()) {
            distancesList.add(
                stopNameAndRespectiveDistanceFromPostalCodeLocationMap.get(busStopKey)
            );
        }
        distancesList.sort();
        return distancesList;
    }

    // public void showRouteOnMap() {
    //     String sourceStop = selectedRoute.subStringBefore(' to ').subStringAfter(' ');
    //     System.debug('Source..@ramda.. ===> ' + sourceStop);
    //     System.debug('@ramda..displaying map...');
    //     HttpRequest request = new HttpRequest();
    //     request.setMethod('GET');
    //     request.setTimeout(10000);
    //     request.setEndpoint(
    //         'https://maps.googleapis.com/maps/api/directions/json?origin='
    //         + EncodingUtil.urlEncode(sourceStop, 'UTF-8')
    //         +'&destination=' + EncodingUtil.urlEncode(selectedSchoolOption, 'UTF-8') +'&avoid=highways&mode=transit&key='
    //         + EncodingUtil.urlEncode(GOOGLE_APIKEY, 'UTF-8')
    //     );
    //
    //     Http http = new Http();
    //     HttpResponse response = http.send(request);
    //     if(200 == response.getStatusCode()) {
    //         shouldDisplayMap = true;
    //     } else {
    //         System.debug('Map was unable to be loaded');
    //     }
    //     mapResponseBody = response.getBody();
    //     System.debug(response);
    // }

    public void checkSeatsAvailability() {
        // if(null == selectedRoute) {
        //     return;
        // }
        System.debug('Selected Route ===> '+selectedRoute);

        stpRouteVehicleList = [
            SELECT Id
                 , Name
                 , Vehicle__r.Name
                 , Vehicle__r.Bus_Capacity__c
                 , Vehicle__r.Driver_Name__c
                 , Vehicle__r.Driver_Phone__c
                 , Stop_Route__r.BusStop__r.Name
                 , Stop_Route__r.BusRoute__r.Name
                 , Stop_Route__r.BusRoute__r.Destination__r.Name
                 , Stop_Route__r.Bus_Arrival_Time_At_Stop__c
              FROM Stop_Route_Vehicle_Jn__c
             WHERE Stop_Route__r.Id =: selectedRoute
               AND Stop_Route__r.BusRoute__r.Destination__r.Id =: selectedSchoolOption
            ];

            System.debug('stpRouteVehicleList ===> ' + stpRouteVehicleList + 'selected school ' + selectedSchoolOption);

            if(true == stpRouteVehicleList.isEmpty()) {
                hasVehicleInformation = false;
                return;
            }
            System.debug('bus capacity: ' + stpRouteVehicleList);
            if (stpRouteVehicleList[0].Vehicle__r.Bus_Capacity__c < ticketsCount) {
                System.debug('@ramda...seats not available ' + renderSeatsNotAvailablePage);
                hasVehicleInformation = false;
            } else {
                hasVehicleInformation = true;
                showCheckBusesResults = false;
            }
            gotoPreviouscheckAvailableRoutesBool = false;
            showPageBlockToEnterPostalCodeAndSelectSchool = false;

            childrenList.clear();
            addNewChildToContactList();
    }

    public void addNewChildToContactList() {
        system.debug('===addNewChildToContactList=====');
        for(Integer index=0; index < ticketsCount; index++) {
            Contact childContactObj = new Contact();
            childrenList.add(childContactObj);
        }
        // Contact childContactObj = new Contact();
        // if(childrenList.size()  > ticketsCount) {
        //     return;
        // }
        // childrenList.add(childContactObj);
        System.debug('add new row ===childrenList====='+childrenList.size() + ' : ' + ticketsCount);
    }

    public void bookTickets() {

        System.debug('@ramda children List: ===> ' + childrenList);

         //Insert the Account record first
            accObj.Name = accountFirstName + ' ' +  accountLastName;
            accObj.BillingStreet = billingStreet;
            System.debug('@ramda Account (Parent) info ===> ' + accObj);
            // if(  null == accObj.Name
            //   || null == accObj.BillingStreet
            //   || null == accObj.Phone
            // ) {
            //     hasConfirmedBooking = false;
            //     return;
            // }

            //validation for contacts
            // for(Contact con : childrenList) {
            //     if(null == con.LastName
            //     || null == con.Blood_Group__c
            //     || null == con.Age__c
            //     || null == con.childClass__c) {
            //         hasConfirmedBooking = false;
            //         return;
            //     }
            // }
            try {
                insert accObj;
            } catch(Exception e) {
                System.debug('Exception: ' + e.getMessage());
            }

            for(Contact con : childrenList) {
                con.AccountId = accObj.Id;
            }

            System.debug('account obj: ==> ' + accObj);

            //Insert the related contacts details
            try {
                insert childrenList;
            } catch(Exception e) {
                System.debug('Exception ===> ' + e.getMessage());
            }

            System.debug('this is @ramda children list:' + childrenList);
            updateVehicleList();

            Booking__c bookingObj = insertInformationToBookingObject();
            if(null != bookingObj) {
                insert bookingObj;
            }

            hasConfirmedBooking = true;
            hasVehicleInformation = false;
            System.debug('ticket booking status: ==> ' + hasConfirmedBooking);
        }

        public void updateVehicleList() {
            List<Vehicle__c> vehicleList = [
                SELECT Id
                     , Bus_Capacity__c
                  FROM Vehicle__c
                 WHERE Name =: stpRouteVehicleList[0].Vehicle__r.Name
            ];

            if( 0 == ticketsCount
             || true == vehicleList.isEmpty()) {
                return;
            }

            vehicleList[0].Bus_Capacity__c -= ticketsCount;
            System.debug('@ramda vehicle list: ' + vehicleList);
            try {
                update vehicleList;
            }
            catch(Exception e) {
                System.debug('Updating....@ramda==> ' + e.getMessage());
            }
        }

        public Booking__c insertInformationToBookingObject() {
            Booking__c bookingObj = new Booking__c();
            bookingObj.Gurdian__c = accObj.Id;
            bookingObj.Boarding_Point__c = stpRouteVehicleList[0].Stop_Route__r.BusStop__r.Name;
            bookingObj.Arrival_Time__c = stpRouteVehicleList[0].Stop_Route__r.Bus_Arrival_Time_At_Stop__c;
            bookingObj.Destination_Point__c = stpRouteVehicleList[0].Stop_Route__r.BusRoute__r.Destination__r.Name;
            bookingObj.Route_Name__c = stpRouteVehicleList[0].Stop_Route__r.BusRoute__r.Name;
            bookingObj.Ticket_Booked__c = true;
            System.debug('Booking object: ==> ' + bookingObj);
            return bookingObj;
        }

        public void moveFromRouteSelectionPageToHomePage() {
            showPageBlockToEnterPostalCodeAndSelectSchool = true;
            showCheckBusesResults = false;
        }

        public void gotoPreviouscheckAvailableRoutes() {
            showCheckBusesResults = true;
            hasVehicleInformation = false;
            gotoPreviouscheckAvailableRoutesBool = true;
        }

        public Map<String, Object> fetchLatLngForPostalCode() {

            Map<String, Object> locationMap;
            HttpResponse response = fetchLocationResponse();
            if(200 != response.getStatusCode()) {
                return locationMap;
            }
            System.debug('...response.getBody(): ' + response.getBody());
            Map<String, Object> responseMap =  (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            List<Object> resultList = (List<Object>) responseMap.get('results');

            if(null == responseMap || true == resultList.isEmpty()) {
                return locationMap;
            }

            Map<String, Object> resultMap = (Map<String, Object>)resultList[0];
            Map<String, Object> geometryMap = (Map<String, Object>)resultMap.get('geometry');
            locationMap = (Map<String, Object>)geometryMap.get('location');
            //locationLatLng = locationMap.get('lat') + COMA + locationMap.get('lng');
            System.debug('...locationMap: ' + locationMap);
            return locationMap;
        }
        public HttpResponse fetchLocationResponse() {
            String ADDKEY = '&key=';

            System.debug('selected school: ==>'+selectedSchoolOption);
            System.debug('postal code: ==>'+postalCode);

            String GEOCODING_URI_BASE = 'https://maps.googleapis.com/maps/api/geocode/json?address=';
            HttpRequest request = new HttpRequest();
            request.setMethod('GET');
            request.setTimeout(10000);
            request.setEndpoint(GEOCODING_URI_BASE
                + EncodingUtil.urlEncode(postalCode, 'UTF-8')
                + ADDKEY
                + EncodingUtil.urlEncode(GOOGLE_APIKEY, 'UTF-8')
            );
            Http http = new Http();
            HttpResponse response = http.send(request);
            return response;
        }



        // public void removeChildRow() {
        //     childrenList.remove(rowToRemove);
        // }

        public void goToHomePage() {
            System.debug('redirecting to : ' + Page.BusServiceVFPage);
            Page.BusServiceVFPage.setRedirect(true);
        }
}
