(* This Source Code Form is subject to the terms of the Mozilla Public License,
   v. 2.0. If a copy of the MPL was not distributed with this file, You can
   obtain one at https://mozilla.org/MPL/2.0/ *)

module E = Infra.Environment
module D = Domain

module type OFFRE = sig
  type ('res, 'err) query_result =
    ('res, ([> Caqti_error.call_or_retrieve ] as 'err)) result Lwt.t

  val create_contrat :
      sigle : string
      -> description : string
      -> (unit, ([> Caqti_error.call_or_retrieve ] as 'err)) query_result

  val create_entreprise : 
        id : int option
    -> libelle : string
    -> description : string
    -> numero : string
    -> rue : string
    -> code_postal : int
    -> ville : string
    -> (unit, ([> Caqti_error.call_or_retrieve ] as 'err)) query_result

  val create :
       id : int option
    -> titre : string
    -> description : string
    -> created_at : Date.t
    -> end_at : Date.t
    -> entreprise : int
    -> contrat : string   
    -> contact: D.Email.t
    -> duree : int option
    -> (unit, ([> Caqti_error.call_or_retrieve ] as 'err)) query_result

  val update :
  
  titre : string
  -> description : string
  -> created_at : Date.t
  -> end_at : Date.t
  -> entreprise : int
  -> contrat : string   
  -> contact: D.Email.t
  -> duree : int option
  -> id : int
    -> (unit, ([> Caqti_error.call_or_retrieve ] as 'err)) query_result

  val delete :
        id:int
    ->  (unit, ([> Caqti_error.call_or_retrieve ] as 'err)) query_result

  val get_by_id :
        id:int 
      -> (D.Offre.t, ([> Caqti_error.call_or_retrieve ] as 'err)) query_result
      
  (*val get_all_by_ville :
      ville : string 
    -> (D.Offre.t list, ([> Caqti_error.call_or_retrieve ] as 'err)) query_result*)
end

module Offre (Connection : Caqti_lwt.CONNECTION) : OFFRE = struct
  let connection : (module Caqti_lwt.CONNECTION) = (module Connection)
  module Email = struct 
    type t = D.Email.t
    let t =
      let encode email = Ok (D.Email.show email) in
      let decode email = D.Email.make email in
      Caqti_type.(custom ~encode ~decode string)
  end

  module Date = struct
    type t = Date.t
    let t = 
      let encode date = Ok (Date.show date) in
      let decode date = Ok (Date.of_string date ) in
      Caqti_type.(custom ~encode ~decode string)
  end


  module Entreprise = struct
    type t = D.Entreprise.t
    let t = 
      let encode entreprise = Ok (D.Entreprise.show entreprise)in
      let decode entreprise = Ok (D.Entreprise.of_string entreprise) in
      Caqti_type.(custom ~encode ~decode string)
  end

  module Contrat = struct
    type t = D.Contrat.t
    let t = 
      let encode contrat = Ok (D.Contrat.show contrat)in
      let decode contrat = Ok(D.Contrat.of_string contrat) in
      Caqti_type.(custom ~encode ~decode string)
  end

  type ('res, 'err) query_result =
    ('res, ([> Caqti_error.call_or_retrieve ] as 'err)) result Lwt.t

    let create_contrat = 
      connection
      |> [%rapper
           execute
          {sql|
          INSERT INTO "Contrat" (sigle,description) 
          VALUES  (%string{sigle}, %string{description})
          |sql}]


    let create_entreprise = 
      connection
      |> [%rapper
           execute
          {sql|
          INSERT INTO "Entreprise" (id, libelle, description, numero, rue, code_postal, ville) 
          VALUES  (%int?{id}, %string{libelle}, %string{description}, 
                  %string{numero}, %string{rue}, 
                  %int{code_postal}, %string{ville})
          |sql}]

    let create =
      connection
      |> [%rapper
           execute
          {sql|
          INSERT INTO "Offre" (id, titre, description, created_at, end_at, id_entreprise, type_contrat, contact, duree) 
          VALUES  (%int?{id}, %string{titre}, %string{description}, 
                  %Date{created_at}, %Date{end_at}, 
                  %int{entreprise}, %string{contrat}, 
                  %Email{contact}, %int?{duree})
          |sql}]

    let update = 
      connection
      |> [%rapper
           execute
           {sql|
            UPDATE "Offre" SET titre=%string{titre},
                              description = %string{description}, 
                              created_at = %Date{created_at}, 
                              end_at = %Date{end_at}, 
                              id_entreprise = %int{entreprise}, 
                              type_contrat = %string{contrat}, 
                              contact = %Email{contact}, 
                              duree = %int?{duree}
            WHERE id = %int{id}
           |sql}]

    let delete = 
      connection
      |> [%rapper
        execute
        {sql|
          DELETE FROM "Offre" 
          WHERE id = %int{id}
        |sql}]

    let get_by_id = 
      connection
      |>
      let open D.Offre in
      [%rapper get_one
        {sql|
          SELECT @int?{id}, @string{titre}, @string{description}, 
            @Date{created_at}, @Date{end_at},
            @Entreprise{entreprise},
            @Contrat{contrat},
            @Email{contact},
            @int?{duree}
          FROM "Offre" off
          JOIN "Entreprise" ent ON ent.id = off.id_entreprise
          JOIN "Contrat" con ON con.sigle = off.type_contrat
          WHERE id = %int{id}
        |sql} 
        record_out]
end
(*ent.id||'#'||ent.libelle||'#'||ent.description||'#'||ent.numero||'#'||ent.rue||'#'||ent.code_postal||'#'||ent.ville

@Contrat{con.sigle||'#'||con.description}*)