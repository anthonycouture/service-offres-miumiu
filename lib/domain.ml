
let parser str= (*it's used to parse data from DB into our domain*)
  let get_lt_from_fold (lt,_)= lt in  
  String.split_on_char ',' str 
  |> List.fold_left (fun (lt,sub) s -> 
    let last_char s = String.get s @@ String.length s -1 in
    match String.get s 0 with
    | '"' when last_char@@s != '"' -> (lt,sub^(String.sub s 1 @@ String.length s -1))  
    | _   when last_char@@s  = '"' -> 
            let rm_quote =( String.sub s (if String.get s 0 = '"' then 1 else 0) @@ String.length s -1) in
            let rm_last_quote = (String.sub rm_quote 0 @@ String.length rm_quote-1) in
            let clean_txt = if last_char@@rm_quote = '"' then rm_last_quote else rm_quote in
              ((if sub <> "" then sub ^ ", " ^ clean_txt else clean_txt)::lt,"")
    | _ when sub <> "" -> (lt,sub ^ ", " ^ s)
    | _ -> (s::lt,sub)) ([],"") |> get_lt_from_fold |> List.rev

module Uuid = struct
  include Uuidm
    (* This Source Code Form is subject to the terms of the Mozilla Public License,
   v. 2.0. If a copy of the MPL was not distributed with this file, You can
   obtain one at https://mozilla.org/MPL/2.0/ *)

  let make uuid_string =
    Uuidm.of_string uuid_string |> Option.to_result ~none:"Invalid_Uuid"


  let show u = to_string u

  let to_yojson uuid = `String (show uuid)

  let of_yojson json = make @@ Yojson.Safe.to_string json
end

module Email = struct
    (* This Source Code Form is subject to the terms of the Mozilla Public License,
   v. 2.0. If a copy of the MPL was not distributed with this file, You can
   obtain one at https://mozilla.org/MPL/2.0/ *)
  type t = Emile.address [@@deriving show]

  let make email =
    let maked_email = Emile.address_of_string email in
    match maked_email with
    | Ok address -> Ok address
    | Error _ -> Error "Invalid_Email"

  let to_string email = email |> Emile.address_to_string

  let to_yojson email = Yojson.Safe.from_string @@ show email

  let of_yojson json = make @@ Yojson.Safe.to_string json
end

module Entreprise = 
struct 
  type t = {
    id : Uuid.t;
    libelle : string;
    description : string;
    numero : string;
    rue : string; 
    code_postal : int;
    ville : string 
  }
  [@@deriving make, show, yojson]

  let ville_list (lt:string list) = Yojson.Safe.from_string @@ Yojson.Safe.to_string @@`Assoc [ "villes",`List (List.map (fun e -> `String e) lt) ]

  let to_yojson entreprise =
    `Assoc [
       "id",  (Uuid.to_yojson entreprise.id); 
       "libelle", `String entreprise.libelle;
       "description", `String entreprise.description;
       "numero", `String entreprise.numero;
       "rue", `String entreprise.rue;
       "code_postal", `Int entreprise.code_postal;
       "ville", `String entreprise.ville
    ]

  let of_string str= 
    let str_without_parenthesis = String.sub str 1 @@ (String.length str) - 2 in
      let split_on_char = parser str_without_parenthesis in
      let id = Result.value ~default:Uuid.nil @@ Uuid.make @@ List.nth split_on_char 0
      and libelle = List.nth split_on_char 1
      and description = List.nth split_on_char 2
      and numero = List.nth split_on_char 3
      and rue = List.nth split_on_char 4
      and code_postal = int_of_string @@ List.nth split_on_char 5
      and ville = List.nth split_on_char 6 in
      make ~id ~libelle ~description ~numero ~rue ~code_postal ~ville 

  let to_yojson_as_list ent = Yojson.Safe.from_string @@ Yojson.Safe.to_string @@ `Assoc ["entreprises",`List  
  ( List.map (fun a -> to_yojson a) ent)]   
end

module Contrat =
struct 
  type t = {
    id : Uuid.t;
    sigle : string;
    description : string
  }
  [@@deriving make, show, yojson]

  let to_yojson contrat =
    `Assoc [
       "id", (Uuid.to_yojson contrat.id);
       "sigle", `String contrat.sigle; 
       "description", `String contrat.description
    ]

  let of_string str= 
    let str_without_parenthesis = String.sub str 1 @@ (String.length str) - 2 in
    let split_on_char = parser str_without_parenthesis in
    let id = Result.value ~default:Uuid.nil @@Uuid.make @@ List.nth split_on_char 0
    and sigle = List.nth split_on_char 1
    and description = List.nth split_on_char 1 in
    make ~id ~sigle ~description 
  
   let to_yojson_as_list contrats = Yojson.Safe.from_string @@ Yojson.Safe.to_string @@ `Assoc 
  ( List.map (fun a -> (Uuid.show a.id),to_yojson a) contrats)

end

module Offre = struct
  type t = {
    id : Uuid.t;
    titre : string;
    description : string;
    created_at : Date.t;
    end_at : Date.t;
    
    entreprise : Entreprise.t;
    contrat : Contrat.t;
    contact : Email.t;
    duree : int option;
    membre_id : Uuid.t
  }
  [@@deriving make, show, yojson]

  let to_yojson offre =
    Yojson.Safe.from_string @@ Yojson.Safe.to_string @@
      `Assoc (
        List.append [
          "id", (Uuid.to_yojson offre.id); 
          "titre", `String offre.titre;
          "description", `String offre.description;
          "created_at", `String (Date.show offre.created_at) ;
          "end_at",  `String (Date.show offre.end_at);
          "entreprise",Entreprise.to_yojson offre.entreprise;
          "contrat", Contrat.to_yojson offre.contrat;
          "contact", `String (Email.show@@ offre.contact);]
          @@
          Option.value ~default:[] @@Option.bind offre.duree (fun d -> Some ["duree", `Int d])
          )
        
      

  let to_yojson_as_list offres = Yojson.Safe.from_string @@ Yojson.Safe.to_string @@ `Assoc 
  ( List.map (fun (ope,a) ->
      let oav = float_of_int@@ List.length offres 
      and njr = float_of_int@@ Date.diff a.end_at a.created_at  in
      let njr_protect_from_zero = if njr=0. then 1. else njr in
      let ranking = (oav-.(float_of_int@@ope)) /. njr_protect_from_zero in

      (string_of_float ranking)^"#"^Uuid.show a.id,to_yojson a) offres)

  module Disable = struct
    type t = {
      id:Uuid.t;
      titre:string;
      membre_id:Uuid.t;
      entreprise : Entreprise.t;
      contrat : Contrat.t;
      created_at : Date.t;
      end_at : Date.t  
    }[@@deriving make, show, yojson]
    
    let of_nuplet (id,titre,membre_id,entreprise,contrat,created_at,end_at) = make ~id ~titre ~membre_id ~entreprise ~contrat ~created_at ~end_at

    let to_yojson t =
      `Assoc[
        "id",(Uuid.to_yojson t.id)
        ; "titre",`String t.titre
        ; "entreprise",Entreprise.to_yojson t.entreprise
        ; "contrat", Contrat.to_yojson t.contrat
        ; "created_at",`String (Date.show t.created_at) 
        ; "end_at",  `String (Date.show t.end_at) 
        ]

    let to_list_yojson (lt:t list) =  Yojson.Safe.from_string @@ Yojson.Safe.to_string @@
      `Assoc (List.map (fun t -> (Uuid.show t.id),(to_yojson t)) lt)
  end
end

let empty_yojson = `Assoc[]