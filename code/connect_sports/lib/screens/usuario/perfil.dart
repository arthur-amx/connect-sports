import 'package:flutter/material.dart';

class PerfilScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Meu Perfil"), backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 20),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 10,
                    color: Colors.white.withOpacity(0.95),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person, size: 80, color: Colors.black),
                          Text(
                            "Meu Perfil",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 20),
                          ListTile(
                            leading: Icon(Icons.person, color: Colors.black),
                            title: Text(
                              "Nome Completo",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text("Seu Nome Aqui"),
                          ),
                          Divider(),
                          ListTile(
                            leading: Icon(Icons.email, color: Colors.black),
                            title: Text(
                              "E-mail",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text("seuemail@exemplo.com"),
                          ),
                          Divider(),
                          ListTile(
                            leading: Icon(Icons.phone, color: Colors.black),
                            title: Text(
                              "Telefone",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text("(00) 00000-0000"),
                          ),
                          Divider(),
                          ListTile(
                            leading: Icon(Icons.cake, color: Colors.black),
                            title: Text(
                              "Data de Nascimento",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text("01/01/2000"),
                          ),
                          Divider(),
                          ListTile(
                            leading: Icon(
                              Icons.fitness_center,
                              color: Colors.black,
                            ),
                            title: Text(
                              "Peso",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text("75 kg"),
                          ),
                          Divider(),
                          ListTile(
                            leading: Icon(Icons.height, color: Colors.black),
                            title: Text(
                              "Altura",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text("1.75 m"),
                          ),
                          Divider(),
                          ListTile(
                            leading: Icon(
                              Icons.directions_run,
                              color: Colors.black,
                            ),
                            title: Text(
                              "Objetivo",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text("Ganho de massa muscular"),
                          ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              backgroundColor: Colors.black,
                            ),
                            child: Text(
                              "Voltar",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
