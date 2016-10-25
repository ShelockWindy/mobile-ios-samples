#import "VectorMapSampleBaseController.h"
#import "MyMapEventListener.h"


/*
 * A sample demonstrating how to read data from GeoJSON and add clustered Markers to map.
 * Both points from GeoJSON, and cluster markers are shown as Ballons which have dynamic texts
 *
 * NB! Suggestions if you have a lot of points (tens or hundreds of thousands) and clusters:
 * 1. Use Point geometry instead of Balloon or Marker
 * 2. Instead of Balloon with text generate dynamically Point bitmap with cluster numbers
 * 3. Make sure you reuse cluster style bitmaps. Creating new bitmap in rendering has technical cost
 */
@interface ClusteredGeoJsonController : VectorMapSampleBaseController

@end

@interface MyClusterElementBuilder : NTClusterElementBuilder

@end


@implementation ClusteredGeoJsonController

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    // Initialize a local vector data source
    NTProjection* proj = [[self.mapView getOptions] getBaseProjection];
    NTLocalVectorDataSource* vectorDataSource = [[NTLocalVectorDataSource alloc] initWithProjection:proj];
    
    // Initialize a vector layer with the previous data source
    NTClusteredVectorLayer* vectorLayer = [[NTClusteredVectorLayer alloc] initWithDataSource:vectorDataSource clusterElementBuilder: [[MyClusterElementBuilder alloc] init]];
    
    [vectorLayer setMinimumClusterDistance: 75]; // default is 100
    
    // Add the previous vector layer to the map
    [[self.mapView getLayers] add:vectorLayer];
    
    [self.mapView setZoom:3 durationSeconds:0];
    
    // load geoJSON data to the vectorDataSource
    [self readGeoJsonData: @"capitals_3857" forMapView:self.mapView intoDataSource:vectorDataSource];
    
    // Create a map event listener
    MyMapEventListener* mapListener = [[MyMapEventListener alloc] init];
    [self.mapView setMapEventListener:mapListener];
    // MapEventListener needs the data source and the layer to display balloons
    // over the clicked vector elements
    [mapListener setMapView:self.mapView vectorDataSource:vectorDataSource];
    
}

-(void)viewWillDisappear:(BOOL)animated
{
    // Check if the view is closing
    if ([self.navigationController.viewControllers indexOfObject:self] == NSNotFound) {
        [self.mapView setMapEventListener:nil];
    }
    
    [super viewWillDisappear:animated];
}

-(void)readGeoJsonData: (NSString*) fileName forMapView:(NTMapView*)mapView intoDataSource: (NTLocalVectorDataSource*) geometryDataSource
{
    NTBalloonPopupStyleBuilder* balloonPopupStyleBuilder = [[NTBalloonPopupStyleBuilder alloc] init];
    
    // load and parse JSON
    NSString* fullpath = [[NSBundle mainBundle] pathForResource:fileName ofType:@"geojson"];
    if (fullpath != nil) {
        
        // read geojson string
        NSString* json = [NSString stringWithContentsOfFile:fullpath encoding:NSUTF8StringEncoding error:nil];

        // parse geojson
        NTGeoJSONGeometryReader* geoJsonReader = [[NTGeoJSONGeometryReader alloc] init];
        NTFeatureCollection* featureCollection = [geoJsonReader readFeatureCollection:json];
        for (int i = 0; i < [featureCollection getFeatureCount]; i++) {
            NTGeometry *geom = [[featureCollection getFeature:i] getGeometry];
            NTVariant *properties = [[featureCollection getFeature:i] getProperties];
            
            NSString *name = [[properties getObjectElement:@"Capital"] getString];
            NSString *country = [[properties getObjectElement:@"Country"] getString];
            
            // Create Popup
            NTBalloonPopup* popup1 = [[NTBalloonPopup alloc] initWithGeometry:geom
                                                             style:[balloonPopupStyleBuilder buildStyle]
                                                             title:name
                                                            desc:country];
            
            // add all properties as MetaData, so you can use it with click handling
            NTStringVector* keys = [properties getObjectKeys];
            for (int j = 0; j < [keys size]; j++) {
                NSString* key = [keys get:j];
                NTVariant* value = [properties getObjectElement:key];
                [popup1 setMetaDataElement:key element:value];
            }
            
            [geometryDataSource add:popup1];
            
        }
        [NTLog debug:[NSString stringWithFormat:@"Added %d features", [featureCollection getFeatureCount]]];
    } else {
        [NTLog error: [NSString stringWithFormat:@"File %@ not found", fileName]];
    }
}

@end


@interface MyClusterElementBuilder ()

@property NSMutableDictionary* markerStyles;

@end

@implementation MyClusterElementBuilder

-(NTVectorElement*)buildClusterElement:(NTMapPos *)mapPos elements:(NTVectorElementVector *)elements
{
    NTBalloonPopupStyleBuilder* balloonPopupStyleBuilder = [[NTBalloonPopupStyleBuilder alloc] init];
    
    // Create Popup
    int numElements = (int)[elements size];
    NSString* title;
    NSString* desc;
    NTBalloonPopupStyle* style;
    
    // show cluster size as number in Balloon
    // special case when elements = 1, happens when zooming in
    if (numElements == 1){
        
        // Option A - show cluster during zoom in (temporarily) - a bit more smooth
        title = @"…";
        desc = @"";
        style = [balloonPopupStyleBuilder buildStyle];
        
        // Option B - show the only element during zoom in. Deep copy object. A bit less smooth
        title = [(NTBalloonPopup *)[elements get:0] getTitle];
        desc = [(NTBalloonPopup *)[elements get:0] getDescription];
        style =  [(NTBalloonPopup *)[elements get:0] getStyle];
        
    } else {
        title = [NSString stringWithFormat:@"%d",(int)[elements size]];
        desc = @"";
        style = [balloonPopupStyleBuilder buildStyle];
    }
    
    NTBalloonPopup* clusterPopup = [[NTBalloonPopup alloc] initWithPos:mapPos
                                                                 style:style
                                                                 title:title
                                                                  desc:desc];
    // set ClickText to enable zoom in for marker
    [clusterPopup setMetaDataElement:@"ClickText" element:[[NTVariant alloc] initWithString:@"cluster"]];
    return clusterPopup;
}

@end
