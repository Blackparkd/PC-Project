import processing.core.PApplet;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

import java.io.IOException;
import java.util.List;

public class Auxiliar implements Runnable{

    private TCP tcp;
    private Informacao info;
    private Player player;
    private Player enemy1;
    private Player enemy2;
    private Player enemy3;
    private ArrayList<Player> planetas;

    public Auxiliar(TCP tcp, Informacao variavel,Player player,Player enemy1, Player enemy2, Player enemy3,ArrayList<Player> planetas){
        this.tcp = tcp;
        this.info = variavel;
        this.player=player;
        this.enemy1=enemy1;
        this.enemy2=enemy2;
        this.enemy3=enemy3;
        this.planetas=planetas;
    }

    public void run(){
        while (true) {
            try {
                System.out.println(info.opcao);
                info.lock.lock();
                info.waitPostman.await();
                switch(info.opcao) {
                    case LOGIN:
                        info.answer = tcp.login(info.username, info.password);
                        System.out.println(info.answer);
                        if (info.answer.equals("error")) {
                            info.response = Response.ERROR;
                        } else {
                            String[] scores2 = info.answer.split("\\s+");
                            info.Level=scores2[1];
                            info.Wstreak=scores2[2];
                            info.response = Response.DONE;
                        }
                        break;

                    case CREATE_USER:
                        info.answer = tcp.create_account(info.username, info.password);
                        System.out.println(info.answer);
                        if (info.answer.equals("error")) {
                            info.response = Response.ERROR;
                        } else {
                            String[] scores2 = info.answer.split("\\s+");
                            info.Level=scores2[1];
                            info.Wstreak=scores2[2];
                            info.response = Response.DONE;
                        }
                        break;

                    case REMOVE_USER:
                        System.out.println(info.opcao);
                        info.answer = tcp.remove_account(info.username, info.password);
                        info.response = Response.DONE;
                        break;
                    case LOGOUT:
                        System.out.println(info.opcao);
                        info.answer = tcp.logout(info.username, info.password);
                        info.response = Response.DONE;
                        break;
                    case LEADER:
                        System.out.println(info.opcao);
                        String resposta = tcp.leaderboard(info.username, info.password);

                        String[] parts2 = resposta.split("\\s+");
                        int a=0;
                        int b=0;
                        while(a<parts2.length){
                            info.users[b]=parts2[a];
                            info.levels[b]=parts2[a+1];
                            info.wStreak[b]=parts2[a+2];
                            b+=1;
                            a+=3;
                        }


                        info.response = Response.DONE;
                        break;
                    case QUEUE:
                        System.out.println(info.opcao);
                        tcp.join(info.username, info.password);
                        info.response = Response.DONE;

                        new Thread(() -> {
                            try {
                                System.out.println("thread esta a correr");
                                String response = tcp.receive();
                                String[] parts3 = response.split("\\s+");
                                //System.out.println(response);
                                if (parts3[0].equals("GAME")) {
                                    info.np=Integer.parseInt(parts3[1]);
                                    player.keys[0]=false;
                                    player.keys[1]=false;
                                    player.keys[2]=false;
                                    info.answer = response;
                                    System.out.println(info.answer);
                                    System.out.println("COMECOU O JOGOOOO");
                                    info.opcao = State.GAME;
                                }
                            } catch (IOException e) {
                                throw new RuntimeException(e);
                            }
                        }).start();


                        break;


                    case GAME:

                        String response = tcp.receive();
                        System.out.println(response);
                        if(response!=null) {
                            if (response.equals("LOST")) {
                                System.out.println("LLLLLL");

                                String[] scores = this.tcp.scores(info.username).split("\\s+");
                                info.Level=scores[1];
                                info.Wstreak=scores[2];

                                info.opcao = State.AFTER;
                                info.response = Response.SWITCH;
                                info.answer = "You Lost!";
                                break;
                            }

                            else if (response.equals("WON")){
                                System.out.println("WWWWWW");
                                //String r = tcp.won(info.username);
                                String[] scores = this.tcp.scores(info.username).split("\\s+");
                                info.Level=scores[1];
                                info.Wstreak=scores[2];

                                info.opcao = State.AFTER;
                                info.response = Response.SWITCH;
                                info.answer = "You Won!";

                                break;
                            }

                            else {
                                String[] parts = response.split("\\s+");

                                int i = 1;
                                int j = 0;
                                while (i < parts.length) {
                                    if (parts[i].equals("P") == false) {
                                        float posx = Float.parseFloat(parts[i]);
                                        float posy = Float.parseFloat(parts[i + 1]);
                                        float angle = Float.parseFloat(parts[i + 2]);

                                        if (i == 1) {
                                            player.x = posx;
                                            player.y = posy;
                                            player.angle = angle;

                                        } else if (i == 4) {
                                            enemy1.x = posx;
                                            enemy1.y = posy;
                                            enemy1.angle = angle;

                                        } else if (i == 7) {
                                            enemy2.x = posx;
                                            enemy2.y = posy;
                                            enemy2.angle = angle;
                                        } else if (i == 10) {
                                            enemy3.x = posx;
                                            enemy3.y = posy;
                                            enemy3.angle = angle;
                                        }
                                        i += 3;
                                    } else if (parts[i].equals("P")) {
                                        float posx = Float.parseFloat(parts[i + 1]);
                                        float posy = Float.parseFloat(parts[i + 2]);
                                        float rad = Float.parseFloat(parts[i + 3]);

                                        Player planeta = planetas.get(j);
                                        planeta.x = posx;
                                        planeta.y = posy;
                                        planeta.radius = rad;
                                        j += 1;
                                        i += 4;
                                    }

                                }
                                System.out.println(j);


                                if (player.keys[0]) {
                                    tcp.enviainputstr("move#front");
                                }
                                if (player.keys[1]) {
                                    tcp.enviainputstr("move#left");
                                }
                                if (player.keys[2]) {
                                    tcp.enviainputstr("move#right");
                                }

                                info.response = Response.DONE;
                                break;
                            }
                        }




                    info.response = Response.DONE;
                    break;


                    case LEAVE:
                        System.out.println(info.opcao);
                        tcp.sair();
                        info.response = Response.DONE;
                }
                info.waitScreen.signal();
            } catch (InterruptedException | IOException e) {
                throw new RuntimeException(e);
            } finally {
                info.lock.unlock();
            }

        }

    }
}