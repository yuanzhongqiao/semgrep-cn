open Common
open Fpath_.Operators
open Alcotest_ext
module E = Core_error

(*****************************************************************************)
(* Purpose *)
(*****************************************************************************)
(* Unit (and integration) tests exercising the parsers *)

(*****************************************************************************)
(* Constants *)
(*****************************************************************************)

(* ran from the root of the semgrep repository *)
let tests_path = Fpath.v "tests"
let tests_path_parsing = tests_path / "parsing"

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

let parsing_tests_for_lang files lang =
  files
  |> List_.map (fun file ->
         Alcotest_ext.create ~tags:(Test_tags.tags_of_lang lang)
           (Filename.basename file) (fun () ->
             Parse_target.parse_and_resolve_name_fail_if_partial lang file
             |> ignore))

let partial_parsing_tests_for_lang files lang =
  files
  |> List_.map (fun file ->
         Alcotest_ext.create ~tags:(Test_tags.tags_of_lang lang)
           (Filename.basename file) (fun () ->
             let { Parsing_result2.skipped_tokens = errs; _ } =
               Parse_target.parse_and_resolve_name lang file
             in
             if errs =*= [] then
               Alcotest.fail
                 "it should parse partially the file (with some errors)"))

(*****************************************************************************)
(* Tests *)
(*****************************************************************************)

(* Note that here we also use tree-sitter to parse; certain files were not
 * parsing with pfff but parses here
 *)
let lang_parsing_tests () =
  (* TODO: infer dir and ext from lang using Lang helper functions *)
  let pack_parsing_tests_for_lang lang dir ext =
    let slang = Lang.show lang in
    pack_tests_pro slang
      (let dir = tests_path_parsing / dir in
       let files = Common2.glob (spf "%s/*%s" !!dir ext) in
       if files =*= [] then
         failwith (spf "Empty set of parsing tests for %s" slang);
       parsing_tests_for_lang files lang)
  in
  pack_suites "lang parsing testing"
    [
      (* languages with only a tree-sitter parser *)
      pack_parsing_tests_for_lang Lang.Bash "bash" ".bash";
      pack_parsing_tests_for_lang Lang.Csharp "csharp" ".cs";
      pack_parsing_tests_for_lang Lang.Dockerfile "dockerfile" ".dockerfile";
      pack_parsing_tests_for_lang Lang.Lua "lua" ".lua";
      pack_parsing_tests_for_lang Lang.Rust "rust" ".rs";
      pack_parsing_tests_for_lang Lang.Cairo "cairo" ".cairo";
      pack_parsing_tests_for_lang Lang.Swift "swift" ".swift";
      pack_parsing_tests_for_lang Lang.Kotlin "kotlin" ".kt";
      pack_parsing_tests_for_lang Lang.Hack "hack" ".hack";
      pack_parsing_tests_for_lang Lang.Html "html" ".html";
      pack_parsing_tests_for_lang Lang.Xml "xml" ".xml";
      pack_parsing_tests_for_lang Lang.Vue "vue" ".vue";
      pack_parsing_tests_for_lang Lang.R "r" ".r";
      pack_parsing_tests_for_lang Lang.Solidity "solidity" ".sol";
      pack_parsing_tests_for_lang Lang.Julia "julia" ".jl";
      pack_parsing_tests_for_lang Lang.Jsonnet "jsonnet" ".jsonnet";
      pack_parsing_tests_for_lang Lang.Dart "dart" ".dart";
      (* here we have both a Pfff and tree-sitter parser *)
      pack_parsing_tests_for_lang Lang.Java "java" ".java";
      pack_parsing_tests_for_lang Lang.Go "go" ".go";
      pack_parsing_tests_for_lang Lang.Ruby "ruby" ".rb";
      pack_parsing_tests_for_lang Lang.Js "js" ".js";
      pack_parsing_tests_for_lang Lang.C "c" ".c";
      pack_parsing_tests_for_lang Lang.Cpp "cpp" ".cpp";
      (* a few parsing tests where we expect some partials
       * See cpp/parsing_partial/
       *)
      pack_tests_pro "C++ partial parsing"
        (let dir = tests_path_parsing / "cpp" / "parsing_partial" in
         let files = Common2.glob (spf "%s/*.cpp" !!dir) in
         let lang = Lang.Cpp in
         partial_parsing_tests_for_lang files lang);
      pack_parsing_tests_for_lang Lang.Php "php" ".php";
      pack_parsing_tests_for_lang Lang.Ocaml "ocaml" ".ml";
      (* recursive descent parser *)
      pack_parsing_tests_for_lang Lang.Scala "scala" ".scala";
      pack_parsing_tests_for_lang Lang.Clojure "clojure" ".clj";
      pack_parsing_tests_for_lang Lang.Protobuf "protobuf" ".proto";
      pack_parsing_tests_for_lang Lang.Promql "promql" ".promql";
    ]

(* It's important that our parsers generate classic parsing errors
 * exns (e.g., Parsing_error, Lexical_error), otherwise semgrep
 * will report some "Fatal error" and abort.
 *)
let parsing_error_tests () =
  let dir = tests_path / "parsing_errors" in
  pack_tests "Parsing error detection"
    (let tests = Common2.glob (spf "%s/*" !!dir) in
     tests |> Fpath_.of_strings
     |> List_.map (fun file ->
            ( Fpath.basename file,
              fun () ->
                try
                  let lang = Lang.lang_of_filename_exn file in
                  let res = Parse_target.just_parse_with_lang lang !!file in
                  if res.skipped_tokens =*= [] then
                    Alcotest.fail
                      "it should raise a standard parsing error exn or return \
                       partial errors "
                with
                | Parsing_error.Lexical_error _
                | Parsing_error.Syntax_error _ ->
                    () )))

let parsing_rules_tests () =
  let dir = tests_path / "rule_formats" in
  pack_tests "Parsing rules"
    (let tests =
       Common2.glob (spf "%s/*.yaml" !!dir)
       @ Common2.glob (spf "%s/*.json" !!dir)
       (* skipped for now to avoid adding jsonnet as a dependency in our
        * CI: Common2.glob (spf "%s/*.jsonnet" dir)
        *)
     in
     tests |> Fpath_.of_strings
     |> List_.map (fun file ->
            (Fpath.basename file, fun () -> Parse_rule.parse file |> ignore)))

let parsing_rules_with_atd_tests () =
  let dir = tests_path / "rules_v2" in
  let tests1 =
    Common2.glob (spf "%s/*.yaml" !!dir) @ Common2.glob (spf "%s/*.json" !!dir)
  in
  let dir = tests_path / "syntax_v2" in
  let tests2 =
    Common2.glob (spf "%s/*.yaml" !!dir) @ Common2.glob (spf "%s/*.json" !!dir)
  in
  pack_tests "Parsing rules with rule_schema_v2.atd"
    (tests1 @ tests2 |> Fpath_.of_strings
    |> List_.map (fun file ->
           (!!file, fun () -> Parse_rules_with_atd.parse_rules_v2 file |> ignore))
    )

(*****************************************************************************)
(* Tests *)
(*****************************************************************************)

let tests () =
  List.flatten
    [
      lang_parsing_tests ();
      parsing_error_tests ();
      parsing_rules_tests ();
      parsing_rules_with_atd_tests ();
    ]
