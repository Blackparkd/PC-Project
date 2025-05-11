import java.net.Socket;
import java.util.ArrayList;

public class Main {
    public static void main(String[] args) {

        try {
            // IP do servidor
            Socket socket = new Socket("*************", 1); 

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