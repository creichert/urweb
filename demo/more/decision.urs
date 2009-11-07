val decision : Meta.private (option bool)

functor Make (M : sig
                  con paperOther :: {Type}
                  constraint [Id, Decision] ~ paperOther
                  include Conference.INPUT
                          where con paper = [Decision = option bool] ++ paperOther

                  val status : ctx ::: {Unit} -> [[Body] ~ ctx] => $([Id = paperId] ++ paperOther)
                                                                   -> transaction (xml ([Body] ++ ctx) [] [])
              end) : Conference.OUTPUT where con paper = [Decision = option bool] ++ M.paperOther
                                       where con userId = M.userId
                                       where con paperId = M.paperId
                                       where con yourPaperTables = []
