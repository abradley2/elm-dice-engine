module Main exposing (..)

import Accessibility.Widget exposing (required)
import Array.Extra exposing (apply)
import Browser exposing (element)
import Html as H
import Html.Attributes as A
import Html.Events as E
import Json.Decode as D
import Random exposing (Seed)
import Result.Extra as ResultX


type Effect
    = EffCmd (Cmd Msg)
    | EffBatch (List Effect)


fromEffect : Effect -> Cmd Msg
fromEffect eff =
    case eff of
        EffCmd cmd ->
            cmd

        EffBatch cmds ->
            List.map fromEffect cmds |> Cmd.batch


type Msg
    = NoOp


type alias Flags =
    { seed : Seed
    }


type alias Model =
    { initialized : Bool
    , flags : Flags
    }


init : D.Value -> ( Model, Effect )
init flagsJson =
    let
        flagsResult =
            D.decodeValue
                (D.map
                    Flags
                    (D.at [ "seed" ] D.int |> D.map Random.initialSeed)
                )
                flagsJson
    in
    ( { initialized = ResultX.isOk flagsResult
      , flags =
            Result.withDefault
                { seed = Random.initialSeed 0
                }
                flagsResult
      }
    , EffCmd Cmd.none
    )


update : Msg -> Model -> ( Model, Effect )
update msg model =
    case msg of
        NoOp ->
            ( model, EffCmd Cmd.none )


view : Model -> H.Html Msg
view model =
    H.div
        [ A.class "helvetica pa3 bg-black-90 white-80"
        ]
        [ H.div
            [ A.class "pv2" ]
            [ textInputView
                [ required True
                , A.class "w2"
                , A.placeholder "3+"
                , A.id "weapon-skill"
                ]
                (always NoOp)
            , H.br [] []
            , H.label
                [ A.class "f7 fw5"
                , A.for "weapon-skill"
                ]
                [ H.text "Weapon/Ballistic Skill"
                ]
            ]
        , H.div
            [ A.class "pv2" ]
            [ textInputView
                [ required True
                , A.class "w2"
                , A.placeholder "2"
                , A.id "attacks-per-unit"
                ]
                (always NoOp)
            , H.br [] []
            , H.label
                [ A.class "f7 fw5"
                , A.for "attacks-per-unit"
                ]
                [ H.text "Number of Attacking Units" ]
            ]
        , H.div
            [ A.class "pv2" ]
            [ textInputView
                [ required True
                , A.class "w2"
                , A.placeholder "2"
                , A.id "attacks-per-weapon"
                ]
                (always NoOp)
            , H.br [] []
            , H.label
                [ A.class "f7 fw5"
                , A.for "attacks-per-weapon"
                ]
                [ H.text "Attacks per Unit" ]
            ]
        , H.div
            [ A.class "pv2" ]
            [ textInputView
                [ required True
                , A.class "w2"
                , A.placeholder "4"
                , A.id "strength"
                ]
                (always NoOp)
            , H.br [] []
            , H.label
                [ A.class "f7 fw5"
                , A.for "strength"
                ]
                [ H.text "Strength" ]
            ]
        , H.div
            [ A.class "pv2" ]
            [ textInputView
                [ required True
                , A.class "w2"
                , A.placeholder "-2"
                , A.id "armor-penetration"
                ]
                (always NoOp)
            , H.br [] []
            , H.label
                [ A.class "f7 fw5"
                , A.for "armor-penetration"
                ]
                [ H.text "Armor Penetration" ]
            ]
        , H.hr [] []
        , H.div
            [ A.class "pv2" ]
            [ textInputView
                [ required True
                , A.class "w2"
                , A.placeholder "4"
                , A.id "toughness"
                ]
                (always NoOp)
            , H.br [] []
            , H.label
                [ A.class "f7 fw5"
                , A.for "toughness"
                ]
                [ H.text "Toughness" ]
            ]
        , H.div
            [ A.class "pv2" ]
            [ textInputView
                [ required True
                , A.class "w2"
                , A.placeholder "5+"
                , A.id "save"
                ]
                (always NoOp)
            , H.br [] []
            , H.label
                [ A.class "f7 fw5"
                , A.for "save"
                ]
                [ H.text "Armor/Invulnerable Save" ]
            ]
        ]


main : Program D.Value Model Msg
main =
    element
        { update = \msg model -> update msg model |> Tuple.mapSecond fromEffect
        , init = init >> Tuple.mapSecond fromEffect
        , subscriptions = \_ -> Sub.none
        , view = view
        }


textInputView : List (H.Attribute Msg) -> (String -> Msg) -> H.Html Msg
textInputView attrs onInput =
    H.input
        ([ E.onInput onInput
         , A.spellcheck False
         , A.autocomplete False
         , A.class <|
            "input-reset ba bg-black-40 white-80 hover-bn"
                ++ " br-0 bt-0 outline-0 ph2 pv2 hover-bg-black-10"
         ]
            ++ attrs
        )
        []


type alias Die =
    { sides : Int
    , passValue : Int
    , modifier : Maybe Modifier
    }


type Modifier
    = NoMod
    | AddValue Int
    | SubtractValue Int
    | InfluenceNext Modifier
    | Reroll
    | Compare Compare Int Modifier
    | MaybeMod (Maybe Modifier)
    | Batch (List Modifier)


type Compare
    = Lte
    | Gte
    | Eq


rollDie : Random.Seed -> Die -> ( Int, Random.Seed )
rollDie seed die =
    Random.step (Random.int 1 die.sides) seed


applyModifier : Die -> Modifier -> ( Int, Random.Seed ) -> ( Random.Seed, Int, Maybe Modifier )
applyModifier die modifier ( currentVal, seed ) =
    case modifier of
        MaybeMod mMod ->
            mMod
                |> Maybe.map (\mod -> applyModifier die mod ( currentVal, seed ))
                |> Maybe.withDefault ( seed, currentVal, Nothing )

        Compare Lte val nextMod ->
            if currentVal <= val then
                applyModifier die nextMod ( currentVal, seed )

            else
                ( seed, currentVal, Nothing )

        Compare Gte val nextMod ->
            if currentVal >= val then
                applyModifier die nextMod ( currentVal, seed )

            else
                ( seed, currentVal, Nothing )

        Compare Eq val nextMod ->
            if currentVal == val then
                applyModifier die nextMod ( currentVal, seed )

            else
                ( seed, currentVal, Nothing )

        AddValue plusVal ->
            ( seed, currentVal + plusVal, Nothing )

        SubtractValue minusVal ->
            ( seed, currentVal - minusVal, Nothing )

        Reroll ->
            let
                ( nextVal, nextSeed ) =
                    rollDie seed die
            in
            ( nextSeed, nextVal, Nothing )

        InfluenceNext nextMod ->
            ( seed, currentVal, Just nextMod )

        NoMod ->
            ( seed, currentVal, Nothing )

        Batch modlist ->
            List.foldr
                (\mod ( curSeed, curVal, curMod ) ->
                    applyModifier die mod ( curVal, curSeed )
                        |> (\( nextSeed, nextVal, nextMod ) ->
                                ( nextSeed, nextVal, Just <| Batch [ MaybeMod curMod, MaybeMod nextMod ] )
                           )
                )
                ( seed, currentVal, Nothing )
                modlist


type alias Setup =
    { attacks : Int
    , attackModifier : Maybe Modifier
    , strength : Int
    , strengthModifier : Maybe Modifier
    , weaponSkill : Int
    , weaponSkillModifier : Maybe Modifier
    , toughness : Int
    , damage : Int
    , armorPenetration : Int
    , save : Int
    }


type Damage
    = Fixed Int
    | Roll Int


type Phase
    = Attack (List Die)
    | Wound (List Die)
    | Save (List Die)
    | Damage (List Die)
    | Resolve Int


woundPassValue : Setup -> Int
woundPassValue setup =
    if setup.strength >= setup.toughness * 2 then
        2

    else if setup.strength > setup.toughness then
        3

    else if setup.strength == setup.toughness then
        4

    else if setup.strength * 2 <= setup.toughness then
        6

    else
        5


run_ : Random.Seed -> Setup -> Phase -> Phase -> Int
run_ seed setup phase nextPhase =
    case ( phase, nextPhase ) of
        ( Attack dice, Wound woundDice ) ->
            if setup.attacks > 0 then
                run_
                    seed
                    { setup | attacks = setup.attacks - 1 }
                    (Attack <| Die 6 setup.weaponSkill setup.weaponSkillModifier :: dice)
                    nextPhase

            else
                case dice of
                    [] ->
                        run_ seed setup nextPhase (Save [])

                    currentRoll :: nextRolls ->
                        let
                            ( rollValue_, nextSeed_ ) =
                                rollDie seed currentRoll

                            ( nextSeed, rollValue, nextMod ) =
                                setup.attackModifier
                                    |> Maybe.map (\mod -> applyModifier currentRoll mod ( rollValue_, nextSeed_ ))
                                    |> Maybe.withDefault ( nextSeed_, rollValue_, Nothing )

                            modWithAp =
                                Batch
                                    [ MaybeMod nextMod
                                    , SubtractValue setup.armorPenetration
                                    ]

                            nextWounds =
                                if rollValue >= currentRoll.passValue then
                                    Die 6 (woundPassValue setup) (Just modWithAp) :: woundDice

                                else
                                    woundDice
                        in
                        run_
                            nextSeed
                            setup
                            (Attack nextRolls)
                            (Wound nextWounds)

        ( Wound dice, Save saveDice ) ->
            case dice of
                [] ->
                    run_
                        seed
                        setup
                        (Save saveDice)
                        (Resolve 0)

                currentRoll :: nextRolls ->
                    let
                        ( nextSeed, rollValue, nextMod ) =
                            rollDie seed currentRoll
                                |> applyModifier currentRoll (MaybeMod currentRoll.modifier)

                        nextSaves =
                            if rollValue >= currentRoll.passValue then
                                Die 6 setup.save nextMod :: saveDice

                            else
                                saveDice
                    in
                    run_
                        nextSeed
                        setup
                        (Wound nextRolls)
                        (Save nextSaves)

        ( Save dice, Damage damageDice ) ->
            case dice of
                [] ->
                    run_ seed setup (Damage damageDice) (Resolve 0)

                currentRoll :: nextRolls ->
                    let
                        ( nextSeed, rollValue, nextMod ) =
                            rollDie seed currentRoll
                                |> applyModifier currentRoll (MaybeMod currentRoll.modifier)

                        nextDamageDice =
                            if rollValue >= currentRoll.passValue then
                                Die setup.damage 0 nextMod :: damageDice

                            else
                                damageDice
                    in
                    run_
                        nextSeed
                        setup
                        (Wound nextRolls)
                        (Damage nextDamageDice)

        ( Damage dice, Resolve woundCount ) ->
            -1

        ( Resolve result, _ ) ->
            result

        _ ->
            -1


run : Random.Seed -> Setup -> Int
run seed setup =
    run_ seed setup (Attack []) (Wound [])
