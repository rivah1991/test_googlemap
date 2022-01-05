import 'package:flutter/material.dart';

import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
//import 'package:google_map_page/secrets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
//import 'package:provider/provider.dart';

import 'dart:math' show cos, sqrt, asin;

import 'package:test_googlemap/secrets.dart';

//import 'package:test_googlemap/secrets.dart';
/*
 *https://blog.codemagic.io/creating-a-route-calculator-using-google-maps/ 
 */
//import 'provider/location_provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // return MultiProvider(
    // providers: [
    //   ChangeNotifierProvider(
    //     create: (context) => LocationProvider(),
    //     child: MapView(),
    //   )
    //  ],
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MapView(),
      // )
    );
  }
}

class MapView extends StatefulWidget {
  @override
  _MapViewState createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    startAddressFocusNode = FocusNode();
    desrinationAddressFocusNode = FocusNode();
    startAddressFocusNode..addListener(_onFocusChange);
    //_getAddress();
    //  Provider.of<LocationProvider>(context, listen: false).initalization();
  }

  void _onFocusChange() {
    debugPrint("Focus: " + startAddressFocusNode.hasFocus.toString());
  }

  @override
  void dispose() {
    super.dispose();
    startAddressFocusNode.dispose();
    desrinationAddressFocusNode.dispose();
  }

  //final CameraPosition _initialLocation =
  // CameraPosition(target: LatLng(0.0, 0.0));
  GoogleMapController mapController;

  Position _currentPosition;
  String _currentAddress;

  //final startAddressController = TextEditingController();
  //final destinationAddressController = TextEditingController();
  TextEditingController startAddressController = new TextEditingController();
  TextEditingController destinationAddressController =
      new TextEditingController();

  FocusNode startAddressFocusNode = FocusNode();
  FocusNode desrinationAddressFocusNode = FocusNode();

  String _startAddress = '';
  String _destinationAddress = '';
  String _placeDistance;

  Set<Marker> markers = {};

  PolylinePoints polylinePoints;
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];

  // ignore: unused_field
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget _textField({
    TextEditingController controller,
    FocusNode focusNode,
    String label,
    String hint,
    double width,
    Icon prefixIcon,
    Widget suffixIcon,
    Function(String) locationCallback,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.7,
      child: TextField(
        onChanged: (value) {
          locationCallback(value);
        },
        autofocus: true,
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(10.0),
            ),
            borderSide: BorderSide(
              color: Colors.grey[400],
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(10.0),
            ),
            borderSide: BorderSide(
              color: Colors.blue[300],
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.all(15),
          hintText: hint,
        ),
      ),
    );
  }

  // Method for retrieving the current location
  // Méthode de récupération de l'emplacement actuel
  void _getCurrentLocation() async {
    await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            forceAndroidLocationManager: true)
        .then((Position position) async {
      setState(() {
        _currentPosition = position;
        _getAddress();
        // _calculateDistance();
        print('POSITION ACTUELLE: $_currentPosition');
        mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 16.0,
            ),
          ),
        );
      });
      // _getAddress();
    }).catchError((e) {
      print(e);
    });
  }

  // Method for retrieving the address
  // Méthode de récupération de l'adresse
  void _getAddress() async {
    try {
      List<Placemark> p = await placemarkFromCoordinates(
          _currentPosition.latitude, _currentPosition.longitude);

      Placemark place = p[0];

      setState(() {
        _currentAddress =
            '${place.name}, ${place.locality}, ${place.postalCode}, ${place.country}';
        //'${place.locality},${place.country}';
        startAddressController.text = _currentAddress;
        _startAddress = _currentAddress;
        print('ADRESSE ACTUELLE: $startAddressController.text');
      });
    } catch (e) {
      print(e);
    }
  }

  // Method for calculating the distance between two places
  // Méthode de calcul de la distance entre deux lieux
  Future<bool> _calculateDistance() async {
    try {
      // Retrieving placemarks from addresses
      // Récupération des repères d'adresses
      List<Location> startPlacemark = await locationFromAddress(_startAddress);
      List<Location> destinationPlacemark =
          await locationFromAddress(_destinationAddress);

      if (startPlacemark != null && destinationPlacemark != null) {
        // Utilise les coordonnées récupérées de la position actuelle,
        // au lieu de l'adresse si la position de départ est celle de l'utilisateur
        // position actuelle, car il en résulte une meilleure précision..
        Position startCoordinates = _startAddress == _currentAddress
            ? Position(
                latitude: _currentPosition.latitude,
                longitude: _currentPosition.longitude,
                accuracy: null)
            : Position(
                latitude: startPlacemark[0].latitude,
                longitude: startPlacemark[0].longitude);
        Position destinationCoordinates = Position(
            latitude: destinationPlacemark[0].latitude,
            longitude: destinationPlacemark[0].longitude);

        // Marqueur d'emplacement de départr
        Marker _startMarker = Marker(
          markerId: MarkerId('$startCoordinates'),
          position: LatLng(
            startCoordinates.latitude,
            startCoordinates.longitude,
          ),
          infoWindow: InfoWindow(
            title: 'Depart',
            snippet: _startAddress,
          ),
          icon: BitmapDescriptor.defaultMarker,
        );

        // Marqueur d'emplacement de destinationr
        Marker destinationMarker = Marker(
          markerId: MarkerId('$destinationCoordinates'),
          position: LatLng(
            destinationCoordinates.latitude,
            destinationCoordinates.longitude,
          ),
          infoWindow: InfoWindow(
            title: 'Arrivée',
            snippet: _destinationAddress,
          ),
          icon: BitmapDescriptor.defaultMarker,
        );

        // Ajout des marqueurs à la liste
        markers.add(_startMarker);
        markers.add(destinationMarker);

        print('Point de départ: $startCoordinates');
        print('Point d arrivée: $destinationCoordinates');

        Position _northeastCoordinates;
        Position _southwestCoordinates;

        // Calcul pour vérifier que la position relative
        // au cadre, et panoramique et zoom de la caméra en conséquence..
        double miny =
            (startCoordinates.latitude <= destinationCoordinates.latitude)
                ? startCoordinates.latitude
                : destinationCoordinates.latitude;
        double minx =
            (startCoordinates.longitude <= destinationCoordinates.longitude)
                ? startCoordinates.longitude
                : destinationCoordinates.longitude;
        double maxy =
            (startCoordinates.latitude <= destinationCoordinates.latitude)
                ? destinationCoordinates.latitude
                : startCoordinates.latitude;
        double maxx =
            (startCoordinates.longitude <= destinationCoordinates.longitude)
                ? destinationCoordinates.longitude
                : startCoordinates.longitude;

        _southwestCoordinates = Position(latitude: miny, longitude: minx);
        _northeastCoordinates = Position(latitude: maxy, longitude: maxx);

        // Accueillez les deux emplacements dans le
        // vue caméra de la cartep
        await mapController.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              northeast: LatLng(
                _northeastCoordinates.latitude,
                _northeastCoordinates.longitude,
              ),
              southwest: LatLng(
                _southwestCoordinates.latitude,
                _southwestCoordinates.longitude,
              ),
            ),
            80.0,
          ),
        );

        // Calcul de la distance entre les positions de début et de fin
        // avec un chemin droit, sans considérer aucun itinéraire
        // double distanceInMeters = attendre Geolocator ().
        // startCoordinates.latitude,
        // startCoordinates.longitude,
        // destinationCoordinates.latitude,
        // destinationCoordinates.longitude,
        //);

        await _createPolylines(startCoordinates, destinationCoordinates);

        double totalDistance = 0.0;

        // Calcul de la distance totale en ajoutant la distance
        // entre petits segmentss
        for (int i = 0; i < polylineCoordinates.length - 1; i++) {
          totalDistance += _coordinateDistance(
            polylineCoordinates[i].latitude,
            polylineCoordinates[i].longitude,
            polylineCoordinates[i + 1].latitude,
            polylineCoordinates[i + 1].longitude,
          );
        }

        setState(() {
          _placeDistance = totalDistance.toStringAsFixed(2);
          print('DISTANCE: $_placeDistance km');
        });

        return true;
      }
    } catch (e) {
      print(e);
    }
    return false;
  }

  // Formule de calcul de la distance entre deux coordonnées
  // https://stackoverflow.com/a/54138876/119102777
  double _coordinateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // Crée les polylignes pour montrer l'itinéraire entre deux endroits
  // ignore: always_declare_return_types
  _createPolylines(Position start, Position destination) async {
    polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      Secrets.API_KEY, // Google Maps API Key
      PointLatLng(start.latitude, start.longitude),
      PointLatLng(destination.latitude, destination.longitude),
      travelMode: TravelMode.transit,
    );

    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }

    PolylineId id = PolylineId('poly');
    Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.red,
      points: polylineCoordinates,
      width: 3,
    );
    polylines[id] = polyline;
  }

  @override
  Widget build(BuildContext context) {
    // var height = MediaQuery.of(context).size.height;
    //var width = MediaQuery.of(context).size.width;
    return Container(
      // height: height,
      //width: width,
      child: Scaffold(
        //key: _scaffoldKey,
        resizeToAvoidBottomInset: false,
        body: (_currentPosition == null)
            ? Center(
                child: CircularProgressIndicator(),
              )
            : Stack(
                children: <Widget>[
                  // Map View
                  GoogleMap(
                    indoorViewEnabled: true,
                    trafficEnabled: false,
                    markers: markers != null ? Set<Marker>.from(markers) : null,
                    //markers: Set<Marker>.from(markers),
                    initialCameraPosition: CameraPosition(
                        target: LatLng(_currentPosition.latitude,
                            _currentPosition.longitude),
                        zoom: 16),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    mapType: MapType.normal,
                    zoomGesturesEnabled: true,
                    zoomControlsEnabled: true,
                    polylines: Set<Polyline>.of(polylines.values),
                    //  onMapCreated: (GoogleMapController controller) {
                    // mapController = controller;
                    // _getAddress();
                    //},
                    onMapCreated: (controller) => {
                      setState(() {
                        mapController = controller;
                      })
                    },

                    onTap: (coordinate) async {
                      mapController
                          .animateCamera(CameraUpdate.newLatLng(coordinate));

                      // _getCurrentLocation();
                      //_getAddress();
                      List<Placemark> p = await placemarkFromCoordinates(
                          coordinate.latitude, coordinate.longitude);

                      Placemark place = p[0];
                      // Placemark place1 = p[1];
                      //startAddressFocusNode = FocusScope.of(context);
                      //if (!startAddressFocusNode.hasPrimaryFocus) {
                      if (startAddressFocusNode.hasFocus) {
                        try {
                          setState(() {
                            _currentAddress =
                                '${place.name}, ${place.locality}, ${place.postalCode}, ${place.country}';
                            //  startAddressController.text = _currentAddress;
                            //_startAddress = _currentAddress;

                            startAddressController.text = _currentAddress;
                            startAddressController.selection =
                                TextSelection.fromPosition(TextPosition(
                                    offset:
                                        startAddressController.text.length));
                            _startAddress = _currentAddress;
                            print('ADRESSE ACTUELLE');

                            print(
                                'ADRESSE ACTUELLE: $startAddressController.text');
                          });
                        } catch (e) {
                          print(e);
                        }
                      } else {
                        try {
                          setState(() {
                            _currentAddress =
                                '${place.name}, ${place.locality}, ${place.postalCode}, ${place.country}';
                            //  startAddressController.text = _currentAddress;
                            //_startAddress = _currentAddress;

                            destinationAddressController.text = _currentAddress;
                            destinationAddressController.selection =
                                TextSelection.fromPosition(TextPosition(
                                    offset: destinationAddressController
                                        .text.length));
                            _destinationAddress = _currentAddress;
                            print('ADRESSE DESTINATION');

                            print(
                                'ADRESSE DESTINATION: $destinationAddressController.text');
                          });
                        } catch (e) {
                          print(e);
                        }
                      }

                      // _getAddress();
                      // print(coordinate);
                      //print(_currentAddress);
                    },
                  ),

                  // Show zoom buttons
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          ClipOval(
                            child: Material(
                              color: Colors.blue[100], // button color
                              child: InkWell(
                                splashColor: Colors.blue, // inkwell color
                                // ignore: sort_child_properties_last
                                child: SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: Icon(Icons.add),
                                ),
                                onTap: () {
                                  mapController.animateCamera(
                                    CameraUpdate.zoomIn(),
                                  );
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          ClipOval(
                            child: Material(
                              color: Colors.blue[100], // button color
                              child: InkWell(
                                splashColor: Colors.blue, // inkwell color
                                // ignore: sort_child_properties_last
                                child: SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: Icon(Icons.remove),
                                ),
                                onTap: () {
                                  mapController.animateCamera(
                                    CameraUpdate.zoomOut(),
                                  );
                                },
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  // Affiche les champs de saisie et le bouton pour
                  // affichage de l'itinéraire
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white70,
                            borderRadius: BorderRadius.all(
                              Radius.circular(20.0),
                            ),
                          ),
                          width: MediaQuery.of(context).size.width * 0.9,
                          child: Padding(
                            padding:
                                const EdgeInsets.only(top: 5.0, bottom: 5.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                // Text(
                                // 'Places',
                                //style: TextStyle(fontSize: 20.0),
                                //),
                                SizedBox(height: 5),
                                _textField(
                                    label: 'Votre point du depart',
                                    //label:'$placemarkFromCoordinates($_currentPosition)',
                                    //  label:
                                    //'$placemarkFromCoordinates($_currentPosition)',
                                    // hint: '$_currentPosition',
                                    hint: 'Choisissez une point de depart',
                                    prefixIcon: Icon(Icons.looks_one),
                                    suffixIcon: IconButton(
                                      icon: Icon(Icons.my_location),
                                      onPressed: () {
                                        startAddressController.text =
                                            _currentAddress;
                                        _startAddress = _currentAddress;
                                      },
                                    ),
                                    controller: startAddressController,
                                    focusNode: startAddressFocusNode,
                                    width: MediaQuery.of(context).size.width,
                                    locationCallback: (String value) {
                                      setState(() {
                                        _startAddress = value;
                                      });
                                    }),
                                SizedBox(height: 5),
                                _textField(
                                    label: 'Destination',
                                    hint: 'Choisissez la destination',
                                    prefixIcon: Icon(Icons.looks_two),
                                    // suffixIcon: IconButton(
                                    // icon: Icon(Icons.my_location),
                                    //onPressed: () {
                                    // destinationAddressController.text =
                                    //   _currentAddress;
                                    //_startAddress = _currentAddress;
                                    // },
                                    //),
                                    controller: destinationAddressController,
                                    focusNode: desrinationAddressFocusNode,
                                    width: MediaQuery.of(context).size.width,
                                    locationCallback: (String value) {
                                      setState(() {
                                        _destinationAddress = value;
                                      });
                                    }),
                                SizedBox(height: 10),
                                Visibility(
                                  visible:
                                      _placeDistance == null ? false : true,
                                  child: Text(
                                    'DISTANCE: $_placeDistance km',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 5),
                                // ignore: deprecated_member_use
                                RaisedButton(
                                  onPressed: (_startAddress != '' &&
                                          _destinationAddress != '')
                                      ? () async {
                                          startAddressFocusNode.unfocus();
                                          desrinationAddressFocusNode.unfocus();
                                          setState(() {
                                            if (markers.isNotEmpty)
                                              markers.clear();
                                            if (polylines.isNotEmpty) {
                                              polylines.clear();
                                            }
                                            if (polylineCoordinates
                                                .isNotEmpty) {
                                              polylineCoordinates.clear();
                                            }
                                            _placeDistance = null;
                                          });

                                          await _calculateDistance()
                                              .then((isCalculated) {
                                            if (isCalculated) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Calcul de distance reussi'),
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Erreur du calcul à distance'),
                                                ),
                                              );
                                            }
                                          });
                                        }
                                      : null,
                                  color: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: Text(
                                      'Afficher l"itinéraire'.toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Show current location button
                  SafeArea(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding:
                            const EdgeInsets.only(right: 10.0, bottom: 10.0),
                        child: ClipOval(
                          child: Material(
                            color: Colors.orange[100], // button color
                            child: InkWell(
                              splashColor: Colors.orange, // inkwell color
                              // ignore: sort_child_properties_last
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: Icon(Icons.my_location),
                              ),
                              onTap: () {
                                mapController.animateCamera(
                                  CameraUpdate.newCameraPosition(
                                    CameraPosition(
                                      target: LatLng(
                                        _currentPosition.latitude,
                                        _currentPosition.longitude,
                                      ),
                                      zoom: 15.0,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
