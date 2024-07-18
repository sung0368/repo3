import 'package:flutter/material.dart';
import 'package:kakaomap_webview/kakaomap_webview.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String kakaoMapKey = 'b705020ae11155211b64827edbefa6c5';
const String kakaoRestApiKey = '937817f3d6addc9b7707b1e761a0f3cc'; // REST API 키

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kakao Map Multi Locations Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: KakaoMapTest(),
    );
  }
}

class KakaoMapTest extends StatefulWidget {
  @override
  _KakaoMapTestState createState() => _KakaoMapTestState();
}

class _KakaoMapTestState extends State<KakaoMapTest> {
  List<TextEditingController> locationControllers = [TextEditingController()];
  List<List<Map<String, dynamic>>> searchResults = [[]];
  List<int> selectedIndices = [-1];
  List<Map<String, dynamic>> locations = [];
  double centerLat = 0, centerLng = 0;
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(title: Text('여러 장소 지도 표시')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            for (int i = 0; i < locationControllers.length; i++) ...[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: locationControllers[i],
                  decoration: InputDecoration(labelText: '장소 ${i + 1}'),
                ),
              ),
              ElevatedButton(
                child: Text('장소 ${i + 1} 검색'),
                onPressed: isLoading ? null : () async {
                  await searchLocation(i);
                },
              ),
              if (searchResults[i].isNotEmpty && selectedIndices[i] == -1)
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: searchResults[i].length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(searchResults[i][index]['place_name']),
                      subtitle: Text(searchResults[i][index]['address_name']),
                      onTap: () {
                        setState(() {
                          selectedIndices[i] = index;
                        });
                      },
                    );
                  },
                ),
            ],
            ElevatedButton(
              child: Text('인원 추가'),
              onPressed: () {
                setState(() {
                  locationControllers.add(TextEditingController());
                  searchResults.add([]);
                  selectedIndices.add(-1);
                });
              },
            ),
            ElevatedButton(
              child: Text('지도 표시'),
              onPressed: selectedIndices.contains(-1)
                  ? null
                  : () async {
                      await displayMap();
                    },
            ),
            if (isLoading)
              CircularProgressIndicator()
            else if (locations.isNotEmpty)
              Container(
                height: 400,
                child: KakaoMapView(
                  width: size.width,
                  height: 400,
                  kakaoMapKey: kakaoMapKey,
                  lat: centerLat,
                  lng: centerLng,
                  showMapTypeControl: true,
                  showZoomControl: true,
                  markerImageURL:
                      'https://t1.daumcdn.net/localimg/localimages/07/mapapidoc/marker_red.png',
                  customScript: '''
                    var markers = [];
                    ${locations.map((loc) => '''
                      var marker = new kakao.maps.Marker({
                        position: new kakao.maps.LatLng(${loc['y']}, ${loc['x']}),
                        map: map
                      });
                      markers.push(marker);
                    ''').join()}
                    var centerMarker = new kakao.maps.Marker({
                      position: new kakao.maps.LatLng($centerLat, $centerLng),
                      map: map,
                      image: new kakao.maps.MarkerImage(
                        'https://t1.daumcdn.net/localimg/localimages/07/mapapidoc/markerStar.png',
                        new kakao.maps.Size(24, 35)
                      )
                    });
                    markers.push(centerMarker);
                  ''',
                  onTapMarker: (message) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('마커 클릭: $message')));
                  },
                ),
              )
            else
              Center(child: Text('장소를 검색하세요')),
          ],
        ),
      ),
    );
  }

  Future<void> searchLocation(int locationIndex) async {
    setState(() {
      isLoading = true;
      searchResults[locationIndex].clear();
      selectedIndices[locationIndex] = -1;
    });

    try {
      final results = await getCoordinates(locationControllers[locationIndex].text);
      setState(() {
        searchResults[locationIndex] = results;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('주소를 찾는 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> displayMap() async {
    setState(() {
      isLoading = true;
      locations.clear();
    });

    try {
      List<double> lats = [];
      List<double> lngs = [];
      for (int i = 0; i < selectedIndices.length; i++) {
        final location = searchResults[i][selectedIndices[i]];
        lats.add(double.parse(location['y']));
        lngs.add(double.parse(location['x']));
        locations.add({'name': '장소${i + 1}', 'x': double.parse(location['x']), 'y': double.parse(location['y'])});
      }
      centerLat = lats.reduce((a, b) => a + b) / lats.length;
      centerLng = lngs.reduce((a, b) => a + b) / lngs.length;

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('지도 표시 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> getCoordinates(String keyword) async {
    final response = await http.get(
      Uri.parse('https://dapi.kakao.com/v2/local/search/keyword.json?query=$keyword'),
      headers: {'Authorization': 'KakaoAK $kakaoRestApiKey'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['documents'].isNotEmpty) {
        return List<Map<String, dynamic>>.from(data['documents']);
      }
    }
    throw Exception('주소를 찾을 수 없습니다');
  }
}
