import java.io.PrintWriter;
import java.net.Socket;
import java.util.ArrayList;

public class Main {
    public static void main(String[] args) {

        try {
            //Socket socket = new Socket("172.29.208.1",1);         // UNI EDUARDO
            Socket socket = new Socket("192.168.56.1", 1); // CASA EDUARDO

            TCP tcp = new TCP(socket);
            ArrayList<Player> planetas = new ArrayList<>(6);
            for (int i = 0; i < 6; i++) {
                planetas.add(new Player());
            }
            Player player = new Player();
            Player enemy1 = new Player();
            Player enemy2 = new Player();
            Player enemy3 = new Player();
            Informacao info = new Informacao();


            new Thread(new Menu(info, player, enemy1, enemy2, enemy3,planetas)).start();
            new Thread(new Auxiliar(tcp, info, player, enemy1, enemy2, enemy3,planetas)).start();
        } catch (Exception e) {
            System.out.println(e.getMessage());
        }


    }

}