module Main exposing (main)

{- This is a starter app which presents a text label, text field, and a button.
   What you enter in the text field is echoed in the label.  When you press the
   button, the text in the label is reverse.
   This version uses `mdgriffith/elm-ui` for the view functions.
-}

import Browser
import Csv exposing (Csv)
import Display
import Element exposing (..)
import Element.Background as Background
import Element.Font as Font
import Element.Input as Input
import File exposing (File)
import File.Select as Select
import Html exposing (Html)
import Html.Attributes as HA
import Chart
import Utility
import Data exposing (Point, Data, xCoord, yCoord)
import Stat exposing (Statistics, statistics)
import Style
import Svg exposing (Svg)
import Task
import RawData exposing (RawData)
import SampleData
import Table
import ErrorBars


type PlotOption
    = WithErrorBars
    | WithRegression
    | MeanLine


main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Model =
    { filename : Maybe String
    , fileSize : Maybe Int
    , dataText : Maybe String
    , rawData : Maybe RawData
    , data : Data
    , header : Maybe String
    , xMinOriginal : Maybe Float
    , xMaxOriginal : Maybe Float
    , confidence : Maybe Float
    , xColumn : Maybe Int
    , yColumn : Maybe Int
    , xMin : Maybe Float
    , xMax : Maybe Float
    , statistics : Maybe Statistics
    , xLabel : Maybe String
    , yLabel : Maybe String
    , plotType : Chart.GraphType
    , plotOptions : List PlotOption
    , output : String
    }


type Msg
    = NoOp
    | InputXLabel String
    | InputYLabel String
    | InputXMin String
    | InputXMax String
    | InputI String
    | InputJ String
    | InputConfidence String
    | FileRequested
    | FileSelected File
    | LoadContent String
    | LoadData DataSource
    | SelectLinePlot
    | SelectScatterPlot
    | ToggleMeanLine
    | ToggleErrorBars
    | ToggleRegression
    | SetColumns
    | SetRange


type alias Flags =
    {}


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { filename = Nothing
      , fileSize = Nothing
      , dataText = Nothing
      , rawData = Nothing
      , data = []
      , xMinOriginal = Nothing
      , xMaxOriginal = Nothing
      , confidence = Just 1
      , xColumn = Just 0
      , yColumn = Just 1
      , xMax = Nothing
      , xMin = Nothing
      , header = Nothing
      , statistics = Nothing
      , plotType = Chart.Line
      , plotOptions = []
      , xLabel = Nothing
      , yLabel = Nothing
      , output = "Ready!"
      }
    , Cmd.none
    )


subscriptions model =
    Sub.none


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        InputXLabel str ->
            ( { model | xLabel = Just str }, Cmd.none )

        InputYLabel str ->
            ( { model | yLabel = Just str }, Cmd.none )

        InputXMin str ->
            ( { model | xMin = String.toFloat str }, Cmd.none )

        InputXMax str ->
            ( { model | xMax = String.toFloat str }, Cmd.none )

        InputConfidence str ->
            ( { model | confidence = String.toFloat str }, Cmd.none )

        InputI str ->
            ( { model | xColumn = (String.toInt str) |> Maybe.map (\x -> x - 1) }, Cmd.none )

        InputJ str ->
            ( { model | yColumn = (String.toInt str) |> Maybe.map (\x -> x - 1) }, Cmd.none )

        FileRequested ->
            ( model
            , Select.file [ "text/*" ] FileSelected
            )

        FileSelected file ->
            ( { model
                | filename = Just <| File.name file
                , fileSize = Just <| File.size file
              }
            , Task.perform LoadContent (File.toString file)
            )

        SelectLinePlot ->
            ( { model | plotType = Chart.Line }, Cmd.none )

        SelectScatterPlot ->
            ( { model | plotType = Chart.Scatter }, Cmd.none )

        ToggleErrorBars ->
            ( { model | plotOptions = Utility.toggleElement WithErrorBars model.plotOptions }, Cmd.none )

        ToggleMeanLine ->
            ( { model | plotOptions = Utility.toggleElement MeanLine model.plotOptions }, Cmd.none )

        ToggleRegression ->
            ( { model | plotOptions = Utility.toggleElement WithRegression model.plotOptions }, Cmd.none )

        SetRange ->
            let
                newModel =
                    recompute model

                newData =
                    newModel.data |> Stat.filter { xMin = model.xMin, xMax = model.xMax }
            in
                ( { newModel | data = newData, xMin = model.xMin, xMax = model.xMax }, Cmd.none )

        SetColumns ->
            ( recompute model, Cmd.none )

        LoadContent content ->
            ( loadContent content model, Cmd.none )

        LoadData dataSource ->
            let
                content =
                    case dataSource of
                        Hubble1929 ->
                            SampleData.hubble1929

                        TemperatureAnomaly ->
                            SampleData.temperature

                        SeaLevel ->
                            SampleData.sealevel
            in
                ( loadContent content model, Cmd.none )


loadContent : String -> Model -> Model
loadContent content model =
    let
        rawData =
            RawData.get content

        xLabel =
            case rawData of
                Nothing ->
                    Nothing

                Just data ->
                    Utility.listGetAt 0 data.columnHeaders

        yLabel =
            case rawData of
                Nothing ->
                    Nothing

                Just data ->
                    Utility.listGetAt 1 data.columnHeaders

        numericalData =
            case rawData of
                Nothing ->
                    []

                Just rawData_ ->
                    (RawData.toData 0 1 rawData_)
                        |> Maybe.withDefault []

        statistics =
            case numericalData of
                [] ->
                    Nothing

                dataList ->
                    Stat.statistics dataList
    in
        { model
            | dataText = Just content
            , rawData = rawData
            , data = numericalData
            , header = Maybe.map .metadata rawData |> Maybe.map (String.join "\n")
            , xLabel = xLabel
            , yLabel = yLabel
            , xMin = Maybe.map .xMin statistics
            , xMax = Maybe.map .xMax statistics
            , xMinOriginal = Maybe.map .xMin statistics
            , xMaxOriginal = Maybe.map .xMax statistics
            , statistics = statistics
        }


recompute : Model -> Model
recompute model =
    case model.rawData of
        Nothing ->
            model

        Just rawData ->
            let
                i =
                    model.xColumn |> Maybe.withDefault 0

                j =
                    model.yColumn |> Maybe.withDefault 1

                newData =
                    RawData.toData i j rawData
                        |> Maybe.withDefault []

                statistics =
                    Stat.statistics newData
            in
                { model
                    | data = newData
                    , statistics = statistics
                    , xMin = Maybe.map .xMin statistics
                    , xMax = Maybe.map .xMax statistics
                }



--|> Stat.filter { xMin = model.xMin, xMax = model.xMax }
--
-- VIEW
--


view : Model -> Html Msg
view model =
    Element.layout Style.outer
        (column
            [ height fill ]
            [ mainRow model
            , footer model
            ]
        )


mainRow : Model -> Element Msg
mainRow model =
    row [ spacing 24, alignTop ]
        [ dataColumn model
        , statisticsPanel model
        , rightColumn model
        , dataSourceColumn model
        ]


dataSourceColumn : Model -> Element Msg
dataSourceColumn model =
    column [ spacing 12, alignTop, moveDown 50 ]
        [ el [ Font.size 16 ] (text "Sample data")
        , loadContentButton model Hubble1929
        , loadContentButton model TemperatureAnomaly
        , loadContentButton model SeaLevel
        ]


rightColumn : Model -> Element Msg
rightColumn model =
    column [ spacing 8, moveUp 90 ]
        [ viewChart model
        , row [ moveDown 100, spacing 36 ]
            [ row [ spacing 12 ]
                [ linePlotButton model
                , scatterPlotButton model
                ]
            , row [ spacing 12 ]
                [ toggleRegressionButton model
                , toggleMeanLineButton model
                , toggleErrorBarsButton model
                , inputConfidenceLevel model
                ]
            ]
        , column
            [ spacing 8
            , Font.size 11
            , moveRight 50
            , moveUp 105
            ]
            [ el
                [ scrollbarY
                , scrollbarX
                , height (px 95)
                , width (px 800)
                , padding 8
                , Background.color (rgb255 255 255 255)
                , moveDown 220
                , moveLeft 50
                ]
                (text <| headerString model)
            ]
        ]


headerString : Model -> String
headerString model =
    case model.header of
        Nothing ->
            "No header"

        Just str ->
            str


dataColumn : Model -> Element Msg
dataColumn model =
    column Style.mainColumn
        [ column [ spacing 20 ]
            [ column [ spacing 8 ] [ title "Data Explorer", openFileButton model ]
            , column
                [ spacing 8 ]
                [ inputXLabel model, inputYLabel model ]
            , rawDataDisplay model
            ]
        ]


footer : Model -> Element Msg
footer model =
    row Style.footer
        [ downloadSampleCsvFile
        , el [] (text <| "File: " ++ (Display.label "-" model.filename))
        , el [] (text <| fileSizeString model.fileSize)
        ]


fileSizeString : Maybe Int -> String
fileSizeString k =
    let
        maybeSize =
            Maybe.map2 (++) (Maybe.map String.fromInt k) (Just " bytes")
    in
        "Size: " ++ Display.label "-" maybeSize


downloadSampleCsvFile : Element Msg
downloadSampleCsvFile =
    download Style.link
        { url = "https://jxxcarlson.github.io/app/temperature-anomalies.csv"
        , label = el [] (text "Download sample data.csv file")
        }



--
-- CHART
--


viewChart : Model -> Element msg
viewChart model =
    let
        regressionGraph =
            case model.statistics of
                Just stats ->
                    [ stats.leftRegressionPoint, stats.rightRegressionPoint ]
                        |> Chart.graph Chart.Line 0 0 1

                Nothing ->
                    Chart.emptyGraph

        meanlineGraph =
            Chart.graph Chart.Line 0 1 0 (ErrorBars.mean model.data)

        errorBarAnnotation =
            case List.member WithErrorBars model.plotOptions of
                False ->
                    Nothing

                True ->
                    Just <| Chart.errorBars (Maybe.withDefault 1 model.confidence) model.data

        mainChart =
            Chart.setConfidence model.confidence <|
                Chart.chart <|
                    Chart.graph model.plotType 1 0 0 model.data

        finalChart =
            mainChart
                |> Chart.addGraphIf (List.member WithRegression model.plotOptions) regressionGraph
                |> Chart.addGraphIf (List.member MeanLine model.plotOptions) meanlineGraph
    in
        row
            [ Font.size 12
            , width (px 800)
            , height (px 515)
            , Background.color <| rgb255 255 255 255
            , padding 30
            , moveDown 95
            ]
            [ Element.html (Chart.view errorBarAnnotation finalChart) ]



--
-- STATISTICS
--


statisticsPanel : Model -> Element Msg
statisticsPanel model =
    column
        [ spacing 12
        , Font.size 12
        , Background.color (rgb255 245 245 245)
        , width (px 200)
        , height (px 675)
        , paddingXY 8 12
        , moveDown 15
        ]
        [ el []
            (text <| numberOfRowsString model.rawData)
        , el []
            (text <| numberOfColumnsString model.rawData)
        , showIfNot (model.rawData == Nothing) <| xInfoDisplay model
        , showIfNot (model.rawData == Nothing) <| Display.info "y" model.yLabel yCoord model.data
        , showIfNot (model.rawData == Nothing) <| Display.correlationInfo model.data
        , showIfNot (model.rawData == Nothing) <| el [ Font.bold, paddingXY 0 5 ] (text <| "TOOLS")
        , showIfNot (model.rawData == Nothing) <| row [ spacing 12 ] [ el [ Font.bold ] (text <| "Column"), inputI model, inputJ model ]
        , showIfNot (model.rawData == Nothing) <| setColumnsButton model
        , showIfNot (model.rawData == Nothing) <| inputXMin model
        , showIfNot (model.rawData == Nothing) <| inputXMax model
        , showIfNot (model.rawData == Nothing) <| setRangeButton model
        ]


showIf : Bool -> Element msg -> Element msg
showIf condition element =
    case condition of
        True ->
            element

        False ->
            Element.none


showIfNot : Bool -> Element msg -> Element msg
showIfNot condition element =
    case condition of
        True ->
            Element.none

        False ->
            element


xInfoDisplay : Model -> Element msg
xInfoDisplay model =
    case model.plotType of
        Chart.Line ->
            Display.smallInfo "x" model.xLabel xCoord model.data

        Chart.Scatter ->
            Display.info "x" model.xLabel xCoord model.data

        Chart.MeanLine ->
            Display.info "x" model.xLabel xCoord model.data



--
-- RAW DATA DISPLAY
--


numberOfRowsString : Maybe RawData -> String
numberOfRowsString maybeRawData =
    case maybeRawData of
        Nothing ->
            "Rows: -"

        Just rawData ->
            "Rows: " ++ String.fromInt (Table.nRows rawData.data)


numberOfColumnsString : Maybe RawData -> String
numberOfColumnsString maybeRawData =
    case maybeRawData of
        Nothing ->
            "Columns: -"

        Just rawData ->
            "Columns: " ++ String.fromInt (Table.nCols rawData.data)


title : String -> Element msg
title str =
    row [ centerX, Font.bold ] [ text str ]


rawDataDisplay : Model -> Element msg
rawDataDisplay model =
    table Style.table
        { data = model.data
        , columns =
            [ { header = Element.text (Display.label "x" model.xLabel)
              , width = fill
              , view =
                    \point ->
                        Element.text <| Display.stringOfFloat (xCoord point)
              }
            , { header = Element.text (Display.label "y" model.yLabel)
              , width = fill
              , view =
                    \point ->
                        Element.text <| Display.stringOfFloat (yCoord point)
              }
            ]
        }



--
-- INPUT FIELDS
--


inputConfidenceLevel : Model -> Element Msg
inputConfidenceLevel model =
    Input.text [ height (px 24), width (px 48), Font.size 12, paddingXY 8 0 ]
        { onChange = InputConfidence
        , text = Display.label "" (Maybe.map String.fromFloat model.confidence)
        , placeholder = Nothing
        , label = Input.labelLeft [ moveDown 4 ] <| el [] (text "c: ")
        }


inputI : Model -> Element Msg
inputI model =
    Input.text [ width (px 36), height (px 18), Font.size 12, paddingXY 8 0 ]
        { onChange = InputI
        , text =
            Display.label "column i"
                (Maybe.map String.fromInt (Maybe.map (\n -> n + 1) model.xColumn))
        , placeholder = Nothing
        , label = Input.labelLeft [ moveDown 4 ] <| el [] (text "x:")
        }


inputJ : Model -> Element Msg
inputJ model =
    Input.text [ width (px 36), height (px 18), Font.size 12, paddingXY 8 0 ]
        { onChange = InputJ
        , text =
            Display.label "column j"
                (Maybe.map String.fromInt (Maybe.map (\n -> n + 1) model.yColumn))
        , placeholder = Nothing
        , label = Input.labelLeft [ moveDown 4 ] <| el [] (text "y:")
        }


inputXMin : Model -> Element Msg
inputXMin model =
    Input.text [ height (px 18), Font.size 12, paddingXY 8 0 ]
        { onChange = InputXMin
        , text = Display.label "xMin ..." (Maybe.map String.fromFloat model.xMin)
        , placeholder = Nothing
        , label = Input.labelLeft [ moveDown 4 ] <| el [] (text "x min:")
        }


inputXMax : Model -> Element Msg
inputXMax model =
    Input.text [ height (px 18), Font.size 12, paddingXY 8 0 ]
        { onChange = InputXMax
        , text = Display.label "xMax ..." (Maybe.map String.fromFloat model.xMax)
        , placeholder = Nothing
        , label = Input.labelLeft [ moveDown 4 ] <| el [] (text "x max:")
        }


inputXLabel : Model -> Element Msg
inputXLabel model =
    let
        labelText =
            case model.xLabel of
                Nothing ->
                    "Label for x values"

                Just str ->
                    str
    in
        Input.text [ height (px 18), Font.size 12, paddingXY 8 0 ]
            { onChange = InputXLabel
            , text = labelText
            , placeholder = Nothing
            , label = Input.labelLeft [ moveDown 4 ] <| el [] (text "X:")
            }


inputYLabel : Model -> Element Msg
inputYLabel model =
    let
        labelText =
            case model.yLabel of
                Nothing ->
                    "Label for y values"

                Just str ->
                    str
    in
        Input.text [ height (px 18), Font.size 12, paddingXY 8 0, width (px 185) ]
            { onChange = InputYLabel
            , text = labelText
            , placeholder = Nothing
            , label = Input.labelLeft [] <| el [ moveDown 4 ] (text "Y:")
            }



--
-- BUTTONS
--


openFileButton : Model -> Element Msg
openFileButton model =
    basicButton model FileRequested (\_ -> Style.button) "Open data file"


toggleRegressionButton : Model -> Element Msg
toggleRegressionButton model =
    let
        styleF m =
            Style.plainButton ++ [ activeBackground (List.member WithRegression m.plotOptions) ]
    in
        basicButton model ToggleRegression styleF "Regression"


linePlotButton : Model -> Element Msg
linePlotButton model =
    let
        styleF m =
            Style.plainButton ++ [ activeBackground (m.plotType == Chart.Line) ]
    in
        basicButton model SelectLinePlot styleF "Line"


scatterPlotButton : Model -> Element Msg
scatterPlotButton model =
    let
        styleF m =
            Style.plainButton ++ [ activeBackground (m.plotType == Chart.Scatter) ]
    in
        basicButton model SelectScatterPlot styleF "Scatter"


toggleMeanLineButton : Model -> Element Msg
toggleMeanLineButton model =
    let
        styleF m =
            Style.plainButton ++ [ activeBackground (List.member MeanLine model.plotOptions) ]
    in
        basicButton model ToggleMeanLine styleF "Mean line"


toggleErrorBarsButton model =
    let
        styleF m =
            Style.plainButton ++ [ activeBackground (List.member WithErrorBars m.plotOptions) ]
    in
        basicButton model ToggleErrorBars styleF "Error bars"


setColumnsButton : Model -> Element Msg
setColumnsButton model =
    basicButton model SetColumns (\_ -> Style.button) "Set columns"


setRangeButton : Model -> Element Msg
setRangeButton model =
    basicButton model SetRange (\_ -> Style.button) "Set range"


basicButton : Model -> Msg -> (Model -> List (Element.Attr () Msg)) -> String -> Element Msg
basicButton model msg styleFunction label_ =
    row [ centerX ]
        [ Input.button (styleFunction model)
            { onPress = Just msg
            , label = el [ centerX, width (px 85) ] (text label_)
            }
        ]


activeBackground : Bool -> Attr decorative msg
activeBackground flag =
    case flag of
        True ->
            Style.buttonActiveBackground

        False ->
            Style.buttonBackground


type DataSource
    = Hubble1929
    | TemperatureAnomaly
    | SeaLevel


dataSourceAsString : DataSource -> String
dataSourceAsString dataSource =
    case dataSource of
        Hubble1929 ->
            "Hubble 1929"

        TemperatureAnomaly ->
            "Temperature"

        SeaLevel ->
            "Sea level"


loadContentButton : Model -> DataSource -> Element Msg
loadContentButton model dataSource =
    basicButton model (LoadData dataSource) (\_ -> Style.button) (dataSourceAsString dataSource)



--
-- HELPERS
--