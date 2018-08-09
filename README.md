# DPoSPool
Sauco Pool
<br>

#Requirements

- NodeJS, Bower, Gulp<br>
- Git<br>
- Crontab<br>

#Installation

<pre>
git clone https://github.com/Sauco-Apps/sauco-Pool.git
cd sauco-Pool
bash pool.sh install
</pre>

#Controll

<pre>
bash pool.sh start - start pool script
bash pool.sh stop - stop pool script
bash pool.sh help - see all commands
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
