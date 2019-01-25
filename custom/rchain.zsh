alias rchainclean='sbt clean bnfc:clean bnfc:generate'
alias rchaincompile='sbt compile'
alias rchaindocker='sbt node/docker:publishLocal'
alias rchainrecompile='sbt clean bnfc:clean bnfc:generate compile node/docker:publishLocal'
