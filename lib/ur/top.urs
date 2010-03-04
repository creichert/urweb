(** Row folding *)

con folder :: K --> {K} -> Type

val fold : K --> tf :: ({K} -> Type)
           -> (nm :: Name -> v :: K -> r :: {K} -> [[nm] ~ r] =>
               tf r -> tf ([nm = v] ++ r))
           -> tf []
           -> r ::: {K} -> folder r -> tf r

structure Folder : sig
    val nil : K --> folder (([]) :: {K})
    val cons : K --> r ::: {K} -> nm :: Name -> v :: K
               -> [[nm] ~ r] => folder r -> folder ([nm = v] ++ r)
    val concat : K --> r1 ::: {K} -> r2 ::: {K}
                 -> [r1 ~ r2] => folder r1 -> folder r2 -> folder (r1 ++ r2)
    val mp : K1 --> K2 --> f ::: (K1 -> K2) -> r ::: {K1}
             -> folder r -> folder (map f r)
end


val not : bool -> bool

con id = K ==> fn t :: K => t
con record = fn t :: {Type} => $t
con fst = K1 ==> K2 ==> fn t :: (K1 * K2) => t.1
con snd = K1 ==> K2 ==> fn t :: (K1 * K2) => t.2
con fst3 = K1 ==> K2 ==> K3 ==> fn t :: (K1 * K2 * K3) => t.1
con snd3 = K1 ==> K2 ==> K3 ==> fn t :: (K1 * K2 * K3) => t.2
con thd3 = K1 ==> K2 ==> K3 ==> fn t :: (K1 * K2 * K3) => t.3

con mapU = K ==> fn f :: K => map (fn _ :: Unit => f)

con ex = fn tf :: (Type -> Type) =>
            res ::: Type -> (choice :: Type -> tf choice -> res) -> res

val ex : tf :: (Type -> Type) -> choice :: Type -> tf choice -> ex tf

val compose : t1 ::: Type -> t2 ::: Type -> t3 ::: Type
              -> (t2 -> t3) -> (t1 -> t2) -> (t1 -> t3)

val show_option : t ::: Type -> show t -> show (option t)
val read_option : t ::: Type -> read t -> read (option t)

val txt : t ::: Type -> ctx ::: {Unit} -> use ::: {Type} -> show t -> t
          -> xml ctx use []

val map0 : K --> tf :: (K -> Type)
           -> (t :: K -> tf t)
           -> r ::: {K} -> folder r -> $(map tf r)
val mp : K --> tf1 :: (K -> Type) -> tf2 :: (K -> Type)
         -> (t ::: K -> tf1 t -> tf2 t)
         -> r ::: {K} -> folder r -> $(map tf1 r) -> $(map tf2 r)
val map2 : K --> tf1 :: (K -> Type) -> tf2 :: (K -> Type) -> tf :: (K -> Type)
           -> (t ::: K -> tf1 t -> tf2 t -> tf t)
           -> r ::: {K} -> folder r -> $(map tf1 r) -> $(map tf2 r) -> $(map tf r)
val map3 : K --> tf1 :: (K -> Type) -> tf2 :: (K -> Type) -> tf3 :: (K -> Type) -> tf :: (K -> Type)
           -> (t ::: K -> tf1 t -> tf2 t -> tf3 t -> tf t)
           -> r ::: {K} -> folder r -> $(map tf1 r) -> $(map tf2 r) -> $(map tf3 r) -> $(map tf r)

val foldUR : tf :: Type -> tr :: ({Unit} -> Type)
             -> (nm :: Name -> rest :: {Unit}
                 -> [[nm] ~ rest] =>
                       tf -> tr rest -> tr ([nm] ++ rest))
             -> tr [] -> r ::: {Unit} -> folder r -> $(mapU tf r) -> tr r

val foldUR2 : tf1 :: Type -> tf2 :: Type -> tr :: ({Unit} -> Type)
             -> (nm :: Name -> rest :: {Unit}
                 -> [[nm] ~ rest] =>
                       tf1 -> tf2 -> tr rest -> tr ([nm] ++ rest))
             -> tr [] -> r ::: {Unit} -> folder r -> $(mapU tf1 r) -> $(mapU tf2 r) -> tr r

val foldR : K --> tf :: (K -> Type) -> tr :: ({K} -> Type)
             -> (nm :: Name -> t :: K -> rest :: {K}
                 -> [[nm] ~ rest] =>
                       tf t -> tr rest -> tr ([nm = t] ++ rest))
             -> tr [] -> r ::: {K} -> folder r -> $(map tf r) -> tr r

val foldR2 : K --> tf1 :: (K -> Type) -> tf2 :: (K -> Type)
             -> tr :: ({K} -> Type)
             -> (nm :: Name -> t :: K -> rest :: {K}
                 -> [[nm] ~ rest] =>
                       tf1 t -> tf2 t -> tr rest -> tr ([nm = t] ++ rest))
             -> tr []
             -> r ::: {K} -> folder r -> $(map tf1 r) -> $(map tf2 r) -> tr r

val foldR3 : K --> tf1 :: (K -> Type) -> tf2 :: (K -> Type) -> tf3 :: (K -> Type)
             -> tr :: ({K} -> Type)
             -> (nm :: Name -> t :: K -> rest :: {K}
                 -> [[nm] ~ rest] =>
                       tf1 t -> tf2 t -> tf3 t -> tr rest -> tr ([nm = t] ++ rest))
             -> tr []
             -> r ::: {K} -> folder r -> $(map tf1 r) -> $(map tf2 r) -> $(map tf3 r) -> tr r

val mapUX : tf :: Type -> ctx :: {Unit}
            -> (nm :: Name -> rest :: {Unit} -> [[nm] ~ rest] =>
                tf -> xml ctx [] [])
            -> r ::: {Unit} -> folder r -> $(mapU tf r) -> xml ctx [] []

val mapX : K --> tf :: (K -> Type) -> ctx :: {Unit}
           -> (nm :: Name -> t :: K -> rest :: {K}
               -> [[nm] ~ rest] =>
               tf t -> xml ctx [] [])
           -> r ::: {K} -> folder r -> $(map tf r) -> xml ctx [] []

val mapUX2 : tf1 :: Type -> tf2 :: Type -> ctx :: {Unit}
            -> (nm :: Name -> rest :: {Unit}
                -> [[nm] ~ rest] =>
                tf1 -> tf2 -> xml ctx [] [])
            -> r ::: {Unit} -> folder r
            -> $(mapU tf1 r) -> $(mapU tf2 r) -> xml ctx [] []

val mapX2 : K --> tf1 :: (K -> Type) -> tf2 :: (K -> Type) -> ctx :: {Unit}
            -> (nm :: Name -> t :: K -> rest :: {K}
                -> [[nm] ~ rest] =>
                tf1 t -> tf2 t -> xml ctx [] [])
            -> r ::: {K} -> folder r
            -> $(map tf1 r) -> $(map tf2 r) -> xml ctx [] []

val mapX3 : K --> tf1 :: (K -> Type) -> tf2 :: (K -> Type) -> tf3 :: (K -> Type) -> ctx :: {Unit}
            -> (nm :: Name -> t :: K -> rest :: {K}
                -> [[nm] ~ rest] =>
                tf1 t -> tf2 t -> tf3 t -> xml ctx [] [])
            -> r ::: {K} -> folder r
            -> $(map tf1 r) -> $(map tf2 r) -> $(map tf3 r) -> xml ctx [] []

val queryL : tables ::: {{Type}} -> exps ::: {Type}
             -> [tables ~ exps] =>
                  sql_query tables exps
                  -> transaction (list $(exps ++ map (fn fields :: {Type} => $fields) tables))

val query1 : t ::: Name -> fs ::: {Type} -> state ::: Type
             -> sql_query [t = fs] []
             -> ($fs -> state -> transaction state)
             -> state
             -> transaction state

val query1' : t ::: Name -> fs ::: {Type} -> state ::: Type
              -> sql_query [t = fs] []
              -> ($fs -> state -> state)
              -> state
              -> transaction state

val queryI : tables ::: {{Type}} -> exps ::: {Type}
             -> [tables ~ exps] =>
             sql_query tables exps
             -> ($(exps ++ map (fn fields :: {Type} => $fields) tables)
                 -> transaction unit)
             -> transaction unit

val queryX : tables ::: {{Type}} -> exps ::: {Type} -> ctx ::: {Unit} -> inp ::: {Type}
             -> [tables ~ exps] =>
             sql_query tables exps
             -> ($(exps ++ map (fn fields :: {Type} => $fields) tables)
                 -> xml ctx inp [])
             -> transaction (xml ctx inp [])

val queryX1 : nm ::: Name -> fs ::: {Type} -> ctx ::: {Unit} -> inp ::: {Type}
              -> sql_query [nm = fs] []
              -> ($fs -> xml ctx inp [])
              -> transaction (xml ctx inp [])

val queryX' : tables ::: {{Type}} -> exps ::: {Type} -> ctx ::: {Unit} -> inp ::: {Type}
              -> [tables ~ exps] =>
              sql_query tables exps
              -> ($(exps ++ map (fn fields :: {Type} => $fields) tables)
                  -> transaction (xml ctx inp []))
              -> transaction (xml ctx inp [])
val queryX1' : nm ::: Name -> fs ::: {Type} -> ctx ::: {Unit} -> inp ::: {Type}
              -> sql_query [nm = fs] []
              -> ($fs -> transaction (xml ctx inp []))
              -> transaction (xml ctx inp [])
val queryXE' : exps ::: {Type} -> ctx ::: {Unit} -> inp ::: {Type}
              -> sql_query [] exps
              -> ($exps -> transaction (xml ctx inp []))
              -> transaction (xml ctx inp [])

val hasRows : tables ::: {{Type}} -> exps ::: {Type}
              -> [tables ~ exps] =>
    sql_query tables exps
    -> transaction bool

val oneOrNoRows : tables ::: {{Type}} -> exps ::: {Type}
                  -> [tables ~ exps] =>
                  sql_query tables exps
                  -> transaction
                         (option
                              $(exps
                                    ++ map (fn fields :: {Type} => $fields) tables))

val oneOrNoRows1 : nm ::: Name -> fs ::: {Type}
                   -> sql_query [nm = fs] []
                   -> transaction (option $fs)

val oneOrNoRowsE1 : tabs ::: {Unit} -> nm ::: Name -> t ::: Type
                    -> [tabs ~ [nm]] =>
    sql_query (mapU [] tabs) [nm = t]
    -> transaction (option t)

val oneRow : tables ::: {{Type}} -> exps ::: {Type}
             -> [tables ~ exps] =>
             sql_query tables exps
             -> transaction
                    $(exps
                          ++ map (fn fields :: {Type} => $fields) tables)

val oneRow1 : nm ::: Name -> fs ::: {Type}
    -> sql_query [nm = fs] []
    -> transaction $fs

val oneRowE1 : tabs ::: {Unit} -> nm ::: Name -> t ::: Type
               -> [tabs ~ [nm]] =>
    sql_query (mapU [] tabs) [nm = t]
    -> transaction t

val nonempty : fs ::: {Type} -> us ::: {{Unit}} -> sql_table fs us
               -> transaction bool

val eqNullable : tables ::: {{Type}} -> agg ::: {{Type}} -> exps ::: {Type}
                 -> t ::: Type -> sql_injectable (option t)
                 -> sql_exp tables agg exps (option t)
                 -> sql_exp tables agg exps (option t)
                 -> sql_exp tables agg exps bool

val eqNullable' : tables ::: {{Type}} -> agg ::: {{Type}} -> exps ::: {Type}
                  -> t ::: Type -> sql_injectable (option t)
                  -> sql_exp tables agg exps (option t)
                  -> option t
                  -> sql_exp tables agg exps bool
