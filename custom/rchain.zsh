alias rchainclean='sbt clean rholang/bnfc:clean rholang/bnfc:generate'
alias rchaincompile='sbt compile'
alias rchaindocker='sbt node/docker:publishLocal'
alias rchainrecompile='JAVA_OPTIONS="-Xms2G -Xmx4G -Xss2m -XX:MaxMetaspaceSize=1G -Dsbt.task.timings=true -Dsbt.task.timings.on.shutdown=true -Dsbt.task.timings.threshold=2000" sbt clean rholang/bnfc:clean rholang/bnfc:generate compile node/docker:publishLocal'
