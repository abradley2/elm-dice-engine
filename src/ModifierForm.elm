module ModifierForm exposing (..)

import DropdownMenu
import Html as H
import Html.Attributes as A
import Html.Events as E
import Run exposing (Compare(..))
import TextInput


type Effect
    = EffCmd (Cmd Msg)
    | EffBatch (List Effect)


fromEffect : Effect -> Cmd Msg
fromEffect eff =
    case eff of
        EffCmd cmd ->
            cmd

        EffBatch effList ->
            effList
                |> List.map fromEffect
                |> Cmd.batch


type alias Model_ =
    { compareDropdownMenu : DropdownMenu.Model
    , compareCondition : Maybe ( Compare, String )
    , resultDropdownMenu : DropdownMenu.Model
    , resultModifier : Maybe ( ResultType, String )
    , passValue : Maybe Int
    , newPassValue : Maybe Int
    , nextModifierForm : Maybe Model
    }


type Model
    = Model Model_


type ResultType
    = Reroll
    | RerollNew
    | InfluenceNext


type Msg
    = NoOp
    | CompareMenuMsg (DropdownMenu.Msg Compare)
    | ResultMenuMsg (DropdownMenu.Msg ResultType)
    | PassValueChanged String
    | NewPassValueChanged String
    | NextModifierMsg Msg


type ConfigType
    = AttackMod
    | WoundMod
    | SaveMod


init_ : ConfigType -> Model_
init_ configType =
    { compareDropdownMenu = DropdownMenu.init
    , compareCondition = Nothing
    , resultDropdownMenu = DropdownMenu.init
    , resultModifier = Nothing
    , passValue = Nothing
    , newPassValue = Nothing
    , nextModifierForm = Nothing
    }


init : ConfigType -> Model
init configType =
    Model (init_ configType)


update_ : Msg -> Model_ -> ( Model_, Effect )
update_ msg model =
    case msg of
        NextModifierMsg nextModifierMsg ->
            case model.nextModifierForm of
                Just (Model model_) ->
                    let
                        ( nextModifierForm, nextModifierCmd ) =
                            update_ nextModifierMsg model_
                                |> Tuple.mapSecond (fromEffect >> Cmd.map NextModifierMsg >> EffCmd)
                    in
                    ( { model
                        | nextModifierForm = Just (Model nextModifierForm)
                      }
                    , nextModifierCmd
                    )

                _ ->
                    ( model, EffCmd Cmd.none )

        CompareMenuMsg dropdownMenuMsg ->
            let
                ( compareDropdownMenu, dropdownMenuCmd ) =
                    DropdownMenu.update
                        dropdownMenuMsg
                        model.compareDropdownMenu
                        |> Tuple.mapSecond (Cmd.map CompareMenuMsg)
            in
            ( { model
                | compareDropdownMenu = compareDropdownMenu
                , compareCondition =
                    case dropdownMenuMsg of
                        DropdownMenu.ItemSelected compareCondition _ ->
                            Just compareCondition

                        _ ->
                            model.compareCondition
              }
            , EffCmd dropdownMenuCmd
            )

        ResultMenuMsg dropdownMenuMsg ->
            let
                ( resultDropdownMenu, dropdownMenuCmd ) =
                    DropdownMenu.update
                        dropdownMenuMsg
                        model.resultDropdownMenu
                        |> Tuple.mapSecond (Cmd.map ResultMenuMsg)
            in
            ( { model
                | resultDropdownMenu = resultDropdownMenu
                , resultModifier =
                    case dropdownMenuMsg of
                        DropdownMenu.ItemSelected resultModifier _ ->
                            Just resultModifier

                        _ ->
                            model.resultModifier
                , nextModifierForm =
                    case dropdownMenuMsg of
                        DropdownMenu.ItemSelected ( InfluenceNext, _ ) _ ->
                            Just <| Model (init_ AttackMod)

                        DropdownMenu.ItemSelected _ _ ->
                            Nothing

                        _ ->
                            model.nextModifierForm
              }
            , EffCmd dropdownMenuCmd
            )

        _ ->
            ( model, EffCmd Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case model of
        Model model_ ->
            update_ msg model_
                |> Tuple.mapSecond fromEffect
                |> Tuple.mapFirst Model


type alias Config =
    { id : String
    }


view : Model -> Config -> H.Html Msg
view model config =
    case model of
        Model model_ ->
            view_ model_ config


view_ : Model_ -> Config -> H.Html Msg
view_ model config =
    H.div
        [ A.class <| "flex flex-wrap"
        ]
        [ H.div
            [ A.class "flex items-start ml3 mt3" ]
            [ DropdownMenu.view model.compareDropdownMenu
                { selectedLabel = Maybe.map Tuple.second model.compareCondition
                , label = "Compare condition"
                , id = config.id ++ "--compare-condition-dropdown"
                , items =
                    [ ( Eq, "Equal to" )
                    , ( Lte, "Less than or equal to" )
                    , ( Gte, "Greater than or equal to" )
                    ]
                }
                |> H.map CompareMenuMsg
            , TextInput.view
                [ A.class <| "w3"
                ]
                PassValueChanged
            ]
        , H.div
            [ A.class "flex items-start ml3 mt3"
            ]
            [ DropdownMenu.view model.resultDropdownMenu
                { selectedLabel = Maybe.map Tuple.second model.resultModifier
                , label = "Result modifier"
                , id = config.id ++ "--result-modifier-dropdown"
                , items =
                    [ ( Reroll, "Re-roll dice" )
                    , ( RerollNew, "Re-roll new dice" )
                    , ( InfluenceNext, "Apply modifier to next roll" )
                    ]
                }
                |> H.map ResultMenuMsg
            , case model.resultModifier of
                Just ( RerollNew, _ ) ->
                    TextInput.view
                        [ A.class "w3" ]
                        NewPassValueChanged

                _ ->
                    H.text ""
            ]
        , case model.nextModifierForm of
            Just (Model model_) ->
                H.div [] [ view_ model_ { config | id = "next-mod--" ++ config.id } ]
                    |> H.map NextModifierMsg

            Nothing ->
                H.text ""
        ]
