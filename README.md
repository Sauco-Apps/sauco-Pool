# Sauco Pool

Sistema para delegados para automatizar la recompensa a sus votantes
<br>

#Instalación

<pre>
git clone https://github.com/Sauco-Apps/sauco-Pool.git
cd sauco-Pool
bash pool.sh install
</pre>

#Control

<pre>
bash pool.sh start - Iniciar Pool
bash pool.sh stop - Detener Pool
bash pool.sh help - Ver todos los comandos
</pre>

#Si hay problema con la UI ejecutar:
<pre>
    cd sauco-Pool
    cd public_src
    bower install
    npm install
    gulp release
    cd ..
    npm install
    bash pool.sh start
</pre>

#Configuración

Debes editar el archivo "config.json" para configurar tu % a repartir, cada cuanto tiempo, etc

<pre>
    "node": {
		"host": "54.148.29.200", <-- Nodo al cual preguntara
		"port": 4000, <-- Puerto del nodo
		"protocol": "http", <-- Protocolo del nodo
		"network": "mainnet" <-- En que red trabajara
	},
	"db": {
		"dbhost": "0.0.0.0", <-- Ubicación de la base de datos del POOL
		"dbport": "5433", <-- Puerto de la base de datos
		"dbname": "dpospool", <-- Nombre de la BD
		"dbuser": "dpospool", <-- usuario
		"dbpass": "password" <-- Clave
	},
    "delegate": {
		"address": "", <-- Aqui va la dirección de Wallet de tu delegado
		"passwrd1": "passphrase1", <-- Tu clave passphrase
		"passwrd2": " " <-- Si tienes tu cuenta con doble firma, aqui va el segundo passphrase
	},
	"pool": {
		"name": "Sauco Pool", <-- Nombre de tu POOL
		"port": 3000, <-- Puerto de tu POOL (Verificar que este abierto)
		"minvote": 100,
		"showmore": 5, <-- Cantidad de estadisticas mostrara por defecto la UI
		"network_fees": 10, <-- Comisión de la red 
		"pool_fees": 20, <-- % de Saucos forjados que se dejara el Pool
		"withdrawal_time": 43200, <-- Cada cuanto tiempo pagara (milisegundos / 1000)
		"withdrawal_tx_delay": 5, <-- Delay en confirmaciones
		"withdrawal_min": 1, <-- Minimo de Saucos acumulados que pagara
		"withdrawal_pool_fees": [{
				"address": "You fees withdrawal address", <-- Dirección a la cual van tus ganancias del Pool
				"percent": 100 <-- Porcentaje que va a esta cuenta
		}]
	}
</pre>
