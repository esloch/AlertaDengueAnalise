# =============================================================================
# Arquivo de execução do Alerta Dengue: Estado do Maranhão
# =============================================================================

# ssh -f infodengue@info.dengue.mat.br -L 5432:localhost:5432 -nNTC
# 3 arboviroses
# Fortaleza = 2111300

# Cabeçalho ------------------------------
setwd("~/MEGA/Pesquisa/Linhas-de-Pesquisa/e-vigilancia/")
source("AlertaDengueAnalise/config/config_global_2020.R")  #configuracao 
#con <- DenguedbConnect(pass = pw)  
con <- dbConnect(drv = dbDriver("PostgreSQL"), dbname = "dengue", 
                 user = "dengue", host = "localhost", 
                 password = pw)
# parametros especificos -----------------
estado = "Maranhão"
sig = "MA"

# data do relatorio:---------------------
data_relatorio = 202117
#lastDBdate("sinan", 2111300) # ultimo caso registrado
dia_relatorio = seqSE(data_relatorio,data_relatorio)$Termino

# cidades --------------------------------
cidades <- getCidades(uf = estado)[,"municipio_geocodigo"]
#pars <- read.parameters(cidades)
nomeRData <- paste0("alertasRData/aleMA-",data_relatorio,".RData")

# Calcula alerta estadual ------------------ 
t1 <- Sys.time()
ale.den <- pipe_infodengue(cidades, cid10 = "A90", nowcasting = "bayesian",
                           iniSE = 201001, finalday = dia_relatorio, 
                           narule = "arima", dataini = "sinpri", completetail = 0) 
save(ale.den, file = nomeRData)

ale.chik <- pipe_infodengue(cidades, cid10 = "A92.0", nowcasting = "bayesian",
                            iniSE = 201001, finalday = dia_relatorio, 
                            narule = "arima", dataini = "sinpri", completetail = 0)
save(ale.den, ale.chik, file = nomeRData)

ale.zika <- pipe_infodengue(cidades, cid10 = "A92.8", nowcasting = "bayesian",
                            iniSE = 201001, finalday = dia_relatorio, 
                            narule = "arima", dataini = "sinpri", completetail = 0)

save(ale.den, ale.chik, ale.zika, file = nomeRData)
t2 <- Sys.time()-t1

# escrevendo na tabela historico_alerta
restab.den <- tabela_historico(ale.den, iniSE = data_relatorio - 100)
summary(restab.den$inc[restab.den$SE == data_relatorio])
restab.chik <- tabela_historico(ale.chik, iniSE = data_relatorio - 100)
summary(restab.chik$inc[restab.chik$SE == data_relatorio])
restab.zika <- tabela_historico(ale.zika, iniSE = data_relatorio - 100)
summary(restab.zika$inc[restab.zika$SE == data_relatorio])

write_alerta(restab.den)
write_alerta(restab.chik)
write_alerta(restab.zika)

# salvando alerta RData no servidor ----
system(paste("scp", nomeRData, "infodengue@info.dengue.mat.br:/home/infodengue/alertasRData/"))
message("done")


# ----- Fechando o banco de dados -----------
dbDisconnect(con)


########### Memoria da analise

#Iniciado em Setembro de 2020
# optou-se por apresentar analise por regional ampliada de saude: Norte, Sul e Leste
# poucas estacoes meteorologicas validas no Norte e Leste, suas por regional ampliada de saude
# Aw em todos (umid apenas)



