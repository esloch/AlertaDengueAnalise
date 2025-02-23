# =============================================================================
# Arquivo de execução do Alerta Dengue Nacional
# =============================================================================
setwd("~/infodengue")
setwd("/home/claudia/MEGA/Pesquisa/Linhas-de-Pesquisa/e-vigilancia/pipeline/")
# ++++++++++++++++++++++++++++++++++
# Definicao dos alertas a rodar ----
# ++++++++++++++++++++++++++++++++++
source("AlertaDengueAnalise/config/config_global_2020.R") 
#lista de estados com relatorios semanais
#estados_Infodengue  

# PS. se quiser rodar para outros estados sem mexer na configuracao, 
# pode substituir a tabela estados_Infodengue:

estados_Infodengue <- data.frame(
    estado = c("Acre","Amazonas","Amapá", "Pará", "Rondônia", "Roraima" , "Tocantins",
               "Alagoas","Bahia","Ceará","Maranhão","Piauí","Pernambuco","Paraíba","Rio Grande do Norte","Sergipe",
               "Goiás", "Mato Grosso", "Mato Grosso do Sul","Distrito Federal",
               "Espírito Santo", "Minas Gerais", "Rio de Janeiro", "São Paulo",
               "Paraná", "Rio Grande do Sul","Santa Catarina"),
#estado = c("Santa Catarina","Minas Gerais"),
#sigla = c("SC","MG"),
sigla = c("AC","AM","AP","PA","RO","RR","TO",
              "AL","BA","CE","MA","PI","PE","PB","RN","SE",
              "GO","MT","MS","DF",
              "ES","MG","RJ","SP",
              "PR","RS","SC"),
 dengue = TRUE,
  chik = c(T),
#  zika = c(T,T)
 zika = c(F,F,F,F,F,F,F,F,F,T,F,F,F,F,F,F,F,F,F,F,F,T,F,F,F,F,T)
)

ww <- c(10,11,22,23,25:27)
# ++++++++++++++++++++++++
# data do relatorio:----
# ++++++++++++++++++++++++
data_relatorio = 202204
dia_relatorio = seqSE(data_relatorio,data_relatorio)$Termino

# ++++++++++++++++++++++++
# criar diretório para salvar o alerta:----
# ++++++++++++++++++++++++
if(!dir.exists(paste0('AlertaDengueAnalise/main/alertas'))){dir.create(paste0('AlertaDengueAnalise/main/alertas'))}

if(!dir.exists(paste0('AlertaDengueAnalise/main/alertas/',data_relatorio))){dir.create(paste0('AlertaDengueAnalise/main/alertas/',data_relatorio))}


# ++++++++++++++++++++++++
# ----- Conexao ----
# ++++++++++++++++++++++++
# com banco remoto do Infodengue (original)
# ssh -f infodengue@info.dengue.mat.br -L 5432:localhost:5432 -nNTC
con <- dbConnect(drv = dbDriver("PostgreSQL"), dbname = "dengue", 
                 user = "dengue", host = "localhost", 
                 password = pw)

# com banco local SQlite: para implementar ainda 
#con <- dbConnect(RSQLite::SQLite(), 
#                   "AlertaDengueAnalise/mydengue.sqlite")

#dbListTables(con) # verificar se as tabelas estão todas no banco. 
# se estiver vazio, ou o endereco está errado, ou o banco sqlite nao foi criado.

# +++++++++++++++++++++++++
# Pipeline ----
# +++++++++++++++++++++++++

t1 <- Sys.time()

#for(i in 1:nrow(estados_Infodengue)){
for(i in ww){
  estado <- estados_Infodengue$estado[i] 
  sig <- estados_Infodengue$sigla[i]
  
  agravos <- c("dengue","chik","zika")[which(
    estados_Infodengue[i, 3:5] == TRUE)]
  
  # nome do arquivo para salvar alertas (como lista)
  nomeRData <- paste0("ale-",sig,
                      "-",data_relatorio,".RData")  
  
  # cidades --------------------------------
  cidades <- getCidades(uf = estado)[,"municipio_geocodigo"]
  
  res <- list() # guardar tudo numa lista
  # alerta dengue
  if(estados_Infodengue$dengue[estados_Infodengue$estado == estado]) {
    res[["ale.den"]] <- pipe_infodengue(cidades, cid10 = "A90", nowcasting = "bayesian", 
                                        finalday = dia_relatorio, narule = "arima", 
                                        iniSE = 201001, dataini = "sinpri", completetail = 0)
    
    res[["restab.den"]] <- tabela_historico(res[["ale.den"]], iniSE = data_relatorio - 100) # so as ultimas 100 semanas
    save(res, file = paste0('AlertaDengueAnalise/main/alertas/',data_relatorio,'/',nomeRData))
  }
  
  # alerta chik
  if(estados_Infodengue$chik[estados_Infodengue$estado == estado]){
    res[["ale.chik"]] <- pipe_infodengue(cidades, cid10 = "A92", nowcasting = "bayesian", 
                                         finalday = dia_relatorio, narule = "arima", 
                                         iniSE = 201001, dataini = "sinpri", completetail = 0)  
    
    res[["restab.chik"]] <- tabela_historico(res[["ale.chik"]], iniSE = data_relatorio - 100)  # so as ultimas 100 semanas
    save(res, file = paste0('AlertaDengueAnalise/main/alertas/',data_relatorio,'/',nomeRData))
  }
  
  # alerta zika
  if(estados_Infodengue$zika[estados_Infodengue$estado == estado]){
    res[["ale.zika"]] <- pipe_infodengue(cidades, cid10 = "A92.8", nowcasting = "bayesian", 
                                         finalday = dia_relatorio, narule = "arima", 
                                         iniSE = 201001, dataini = "sinpri", completetail = 0)  
    res[["restab.zika"]] <- tabela_historico(res[["ale.zika"]], iniSE = data_relatorio - 100)  # so as ultimas 100 semanas
    save(res, file = paste0('AlertaDengueAnalise/main/alertas/',data_relatorio,'/',nomeRData))
  }
  
  # copiar o arquivo RData para o servidor (o formato mudou! os ale.* estao todos dentro de uma lista)
  system(paste("scp", paste0("AlertaDengueAnalise/main/alertas/",data_relatorio,"/",nomeRData), "infodengue@info.dengue.mat.br:/home/infodengue/alertasRData/"))
  
  
}
t2 <- Sys.time()
message(paste("total time was", t2-t1))

  # ----- Fechando o banco de dados local -----------
dbDisconnect(con)

 
# ++++++++++++++++++++++++
# Write Alerta:----
# ++++++++++++++++++++++++ 
#Diretório definido para os alertas estaduais
file_paths <- fs::dir_ls(paste0("AlertaDengueAnalise/main/alertas/",data_relatorio,"/"))
file_paths 
   
#Load alertas
j <- 1
for (i in seq_along(file_paths)){
    load.Rdata(file_paths[i], "res")
    assign(paste0("res", j),res)
    j = j+1
    load(file_paths[i])
  }
rm(res) 
  
#Unindo dataframe
restab_den <- list()
for (i in seq_along(file_paths)){
  data <- eval(parse(text=paste0("res",i,"[['restab.den']] %>% bind_rows()")))# unlist data
  restab_den[[i]] <-data
}

restab_den <- eval(parse(text =paste0("rbind(",paste0("restab_den[[",seq_along(file_paths),"]]", collapse = ","),")")))


restab_chik <- list()
for (i in seq_along(file_paths)){
  data <- eval(parse(text=paste0("res",i,"[['restab.chik']] %>% bind_rows()")))# unlist data
  restab_chik[[i]] <-data
}

restab_chik <- eval(parse(text =paste0("rbind(",paste0("restab_chik[[",seq_along(file_paths),"]]", collapse = ","),")")))


restab_zika <- list()
for (i in seq_along(file_paths)){
  data <- eval(parse(text=paste0("res",i,"[['restab.zika']] %>% bind_rows()")))# unlist data
  restab_zika[[i]] <-data
}

restab_zika <- eval(parse(text =paste0("rbind(",paste0("restab_zika[[",seq_along(file_paths),"]]", collapse = ","),")")))

summary(restab_chik)
summary(restab_den)
summary(restab_zika)

restab_den$casos_est_max[restab_den$casos_est_max > 10000] <- NA
restab_chik$casos_est_max[restab_chik$casos_est_max > 10000] <- NA
restab_zika$casos_est_max[restab_zika$casos_est_max > 10000] <- NA



# ++++++++++++++++++++++++
# criar diretório para salvar o output.sql:----
# ++++++++++++++++++++++++
if(!dir.exists(paste0('AlertaDengueAnalise/main/sql'))){dir.create(paste0('AlertaDengueAnalise/main/sql'))}

#escrevendo alerta
write_alerta(restab_den, writetofile = TRUE, arq = paste0("AlertaDengueAnalise/main/sql/output_dengue.sql"))
write_alerta(restab_chik, writetofile = TRUE, arq = paste0("AlertaDengueAnalise/main/sql/output_chik.sql"))
write_alerta(restab_zika, writetofile = TRUE, arq = paste0("AlertaDengueAnalise/main/sql/output_zika.sql"))
