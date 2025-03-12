import processing.core.PApplet;
import processing.core.PImage;
import processing.core.PFont;
import java.io.File;
import java.util.ArrayList;
import javax.sound.sampled.AudioInputStream;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.Clip;
import javax.sound.sampled.*;

// PROCESSING PATH //
//  C:\Users\eduar\Downloads\processing-4.3-windows-x64\processing-4.3

enum State {
    MENU,
    CREATE_USER,
    REMOVE_USER,
    LOGGED,
    LOGIN,
    LOGOUT,
    LEADER,
    QUEUE,
    LEAVE,
    GAME,
    AFTER
}



public class Menu extends PApplet implements Runnable{
    PImage menu_inicial;
    PImage menu_login;
    PImage menu_leaderboard;
    PImage menu_waiting;
    PImage menu_game;
    String username="";
    String password="";
    String pass="";
    String copy="";
    int selected;
    boolean enteruser=false;
    boolean enterpass=false;
    Informacao info;
    private State state = State.MENU;
    private int tipomenu;
    Player player;
    Player enemy1;
    Player enemy2;
    Player enemy3;
    ArrayList<Player> planetas = new ArrayList<>();
    int screenWidth=1546;
    int screenHeight=836;
    PFont tipoLetra;

    public Menu(Informacao info, Player player, Player enemy1, Player enemy2, Player enemy3,ArrayList<Player> planetas) {
        this.info = info;
        this.player=player;
        this.enemy1=enemy1;
        this.enemy2=enemy2;
        this.enemy3=enemy3;
        this.planetas=planetas;
    }


    public void settings() {
        size(1546, 836);
        menu_inicial=loadImage("6.jpg");
        menu_inicial.resize(1546, 836);
        menu_login=loadImage("6.jpg");
        menu_login.resize(1546, 836);
        menu_leaderboard=loadImage("6.jpg");
        menu_leaderboard.resize(1546, 836);
        menu_waiting=loadImage("7.jpg");
        menu_waiting.resize(1546,836);
        menu_game=loadImage("8.jpg");
        menu_game.resize(1546,836);

        this.username = "";
        this.password = "";
        this.copy="";
        this.selected = 0;
        this.tipomenu = 0;
    }


    public void draw() {
        if (info.answer.equals("start"))state=info.opcao;
        switch (state) {
            case MENU:
                tipomenu = 0;
                drawMenu1();
                break;
            case LOGGED:
                tipomenu = 2;
                drawMenu2();
                break;
            case LEADER:
                tipomenu = 3;
                drawLeaderboard();
                break;
            case QUEUE:
                tipomenu = 4;
                drawWaitingMenu();
                handleTCPState(State.GAME, State.LOGGED);
                break;
            case GAME:
                tipomenu=5;
                drawGameBoard();
                handleTCPState(State.GAME,State.AFTER);
                break;

            case AFTER:
                drawPostGameMenu();
                break;
        }
    }

    public void keyPressed() {
        if (state==State.MENU && key=='1'){
            state=State.LOGIN;
            fill(211, 211, 211); // Set the fill color to light grey
            text("Username: ",750,290);
            rect(1000, 250, 450, 50); // Text box position and size
            text("Password: ",750,390);
            rect(1000, 350, 450, 50); // Text box position and size

            enteruser=true;
        }

        else if (state==State.MENU && key=='2'){
            state=State.CREATE_USER;
            fill(211, 211, 211); // Set the fill color to light grey
            text("Username: ",750,490);
            rect(1000, 450, 450, 50); // Text box position and size
            text("Password: ",750,590);
            rect(1000, 550, 450, 50); // Text box position and size
            enteruser=true;
        }




        else if(state==State.LOGIN){
            if(enteruser==true){
                if(keyCode!=ENTER && keyCode!=BACKSPACE){
                    username+=key;
                    textSize(35);
                    fill(0); // Text color black
                    text(this.username, 1030, 290); // Position text slightly inside the text box
                }

                else if(keyCode == BACKSPACE){
                    String user2="";
                    if(this.username != null && this.username.length()>0) {
                        user2 = this.username.substring(0,this.username.length() - 1);
                    }
                    this.username=user2;
                    fill(211, 211, 211); // Set the fill color to light grey
                    rect(1000, 250, 450, 50); // Text box position and size
                    fill(0); // Text color black
                    text(this.username, 1030, 290); // Position text slightly inside the text box
                }


                else if(keyCode==ENTER){
                    enteruser=false;
                    enterpass=true;
                }
            }

            else if(enterpass==true){
                if(keyCode!=ENTER && keyCode!=BACKSPACE){
                    password+=key;
                    fill(0); // Text color black
                    text("*".repeat(this.password.length()), 1030, 390); // Position text slightly inside the text box
                }

                else if(keyCode==BACKSPACE){
                    String pass2="";
                    if(this.password != null && this.password.length()>0) {
                        pass2 = this.password.substring(0,this.password.length() - 1);
                    }
                    this.password=pass2;
                    fill(211, 211, 211); // Set the fill color to light grey
                    rect(1000, 350, 450, 50); // Text box position and size
                    fill(0); // Text color black
                    text("*".repeat(this.password.length()), 1030, 390);  // Position text slightly inside the text box
                }
                else if (keyCode==ENTER){
                    System.out.println(username);
                    System.out.println(password);
                    System.out.println("\n\n");
                    enteruser=false;
                    enterpass=false;
                    info.username = username;
                    info.password = password;
                    handleTCPState(State.LOGGED, State.MENU);
                    tipomenu = 1;
                }
            }
        }





        else if (state==State.CREATE_USER) {
            if(enteruser==true){
                if(keyCode!=ENTER && keyCode!=BACKSPACE){
                    username+=key;
                    textSize(35);
                    fill(0); // Text color black
                    text(this.username, 1030, 490);
                }

                else if(keyCode == BACKSPACE){
                    String user2="";
                    if(this.username != null && this.username.length()>0) {
                        user2 = this.username.substring(0,this.username.length() - 1);
                    }
                    this.username=user2;
                    fill(211, 211, 211); // Set the fill color to light grey
                    rect(1000, 450, 450, 50); // Text box position and size
                    fill(0); // Text color black
                    text(this.username, 1030, 490); // Position text slightly inside the text box
                }


                else if(keyCode==ENTER){
                    enteruser=false;
                    enterpass=true;
                }
            }

            else if(enterpass==true){
                if(keyCode!=ENTER && keyCode!=BACKSPACE){
                    password+=key;
                    fill(0); // Text color black
                    text("*".repeat(this.password.length()), 1030, 590); // Position text slightly inside the text box
                }

                else if(keyCode==BACKSPACE){
                    String pass2="";
                    if(this.password != null && this.password.length()>0) {
                        pass2 = this.password.substring(0,this.password.length() - 1);
                    }
                    this.password=pass2;
                    fill(211, 211, 211); // Set the fill color to light grey
                    rect(1000, 550, 450, 50); // Text box position and size
                    fill(0); // Text color black
                    text("*".repeat(this.password.length()), 1030, 590);  // Position text slightly inside the text box
                }


                else if (keyCode==ENTER){
                    System.out.println(username);
                    System.out.println(password);
                    System.out.println("\n\n");
                    enteruser=false;
                    enterpass=false;
                    info.username = username;
                    info.password = password;
                    handleTCPState(State.LOGGED, State.MENU);
                    tipomenu = 1;
                }
            }
        }




        else if(state==State.LOGGED && key=='1'){
            state=State.QUEUE;
        }
        else if(state==State.LOGGED && key=='2'){
            state=State.LEADER;
            handleTCPState(State.LEADER, State.LOGGED);
            tipomenu=3;
        }
        else if(state==State.LOGGED && key=='3'){
            info.username=this.username;
            info.password=this.password;
            state=State.LOGOUT;
            this.username="";
            this.password="";
            info.Level="";
            info.Wstreak="";
            handleTCPState(State.MENU, State.LOGGED);
            tipomenu=0;
        }
        else if(state==State.LOGGED && key=='4'){
            info.username=username;
            info.password=password;
            state=State.REMOVE_USER;
            this.username="";
            this.password="";
            handleTCPState(State.MENU, State.LOGGED);
            tipomenu=0;
        }

        else if(state==State.LEADER && key=='1'){
            state=State.LOGGED;

        }

        else if (state==State.GAME){
            if (key=='w'|| key=='W')
                player.keys[0]=true;
            if (key=='a'|| key=='A')
                player.keys[1]=true;
            if (key=='d'|| key=='D')
                player.keys[2]=true;
        }

        else if (state==State.AFTER && key=='1'){
            state=State.LOGGED;
            info.opcao=State.LOGGED;
        }


    }

    public void keyReleased(){
        if(state==State.GAME) {
            if (key == 'w' || key == 'W')
                player.keys[0] = false;
            if (key == 'a' || key == 'A')
                player.keys[1] = false;
            if (key == 'd' || key == 'D')
                player.keys[2] = false;

        }
    }




    void handleTCPState(State nextState, State errorState) {
        try {

            info.lock.lock();
            info.opcao = state;
            info.waitPostman.signal();
            while (info.response == Response.NOTHING) info.waitScreen.await();

            if (info.response == Response.DONE) {
                state = nextState;
            }
            else if (info.response == Response.SWITCH) {
                if (state == State.LOGIN || state == State.CREATE_USER) {
                    System.out.println("reset");
                    username = "";
                    password = "";
                }
                state = info.opcao;
            } else {
                if (state == State.LOGIN || state == State.CREATE_USER) {
                    System.out.println("reset");
                    username = "";
                    password = "";
                }
                state = errorState;
            }
            info.response = Response.NOTHING;


        } catch (InterruptedException e) {
            throw new RuntimeException(e);
        } finally {
            info.lock.unlock();
        }
    }





    private void drawMenu1() {
        //background(255);
        background(menu_inicial);
        //int textSizeValue = 60; // Set text size as a variable
        //textSize(textSizeValue);
        tipoLetra = createFont("Calibri",80);
        textFont(tipoLetra);
        fill(255, 100, 0); // Set the fill color to a deep sunset-like orange

        text("1 » Login", 50, 300);
        text("2 » Create Account", 50,500);
        textSize(50);
    }
    public void drawMenu2(){
        background(menu_login);
        tipoLetra = createFont("Calibri",80);
        textFont(tipoLetra);
        fill(255, 100, 0); // Set the fill color to a deep sunset-like orange
        textSize(60);
        text("1 » Find a game",50,220);
        text("2 » Leaderboard",50,370);
        text("3 » Log Out",50,520);
        text("4 » Remove account",50,670);

        textSize(40);
        fill(211, 211, 211); // Set the fill color to light grey
        text(this.username,900,220);
        text("Nível: ",900,300);
        text("Vitórias: ",900,380);

        text(info.Level,1000,300);
        text(info.Wstreak,1050,380);

    }

    public void drawLeaderboard(){
        background(menu_leaderboard);
        textSize(45);
        tipoLetra = createFont("Calibri",40);
        textFont(tipoLetra);
        textSize(40);
        fill(0, 204, 204); //dark cyan
        fill(255, 165, 0); // Set the fill color to orange
        fill(255, 100, 0); // Set the fill color to a deep sunset-like orange
        text("User",35,300);
        text("Level",210,300);
        text("Win Streak",370,300);

        textSize(30);
        fill(255, 165, 0); // Set the fill color to orange
        text(info.users[0],50,350);
        text(info.users[1],50,400);
        text(info.users[2],50,450);
        text(info.users[3],50,500);
        text(info.users[4],50,550);
        text(info.users[5],50,600);
        text(info.users[6],50,650);
        text(info.users[7],50,700);
        text(info.users[8],50,750);
        text(info.users[9],50,800);

        text(info.levels[0],250,350);
        text(info.levels[1],250,400);
        text(info.levels[2],250,450);
        text(info.levels[3],250,500);
        text(info.levels[4],250,550);
        text(info.levels[5],250,600);
        text(info.levels[6],250,650);
        text(info.levels[7],250,700);
        text(info.levels[8],250,750);
        text(info.levels[9],250,800);

        text(info.wStreak[0],450,350);
        text(info.wStreak[1],450,400);
        text(info.wStreak[2],450,450);
        text(info.wStreak[3],450,500);
        text(info.wStreak[4],450,550);
        text(info.wStreak[5],450,600);
        text(info.wStreak[6],450,650);
        text(info.wStreak[7],450,700);
        text(info.wStreak[8],450,750);
        text(info.wStreak[9],450,800);

        textSize(45);
        fill(255, 100, 0); // Set the fill color to a deep sunset-like orange
        text("1 » Close",900,800);
    }

    public void drawWaitingMenu(){
        background(menu_waiting);
        tipoLetra = createFont("Calibri",80);
        textFont(tipoLetra);
        textSize(45);
        fill(255, 100, 0); // Set the fill color to a deep sunset-like orange
        text("Waiting for game",620,430);
    }


    public void drawGameBoard() {
        //background(0);
        background(menu_game);
        tipoLetra = createFont("Calibri",80);
        textFont(tipoLetra);
        float lineLength = 25;
        strokeWeight(3);

        for(int i=0; i<info.np; i++){
            if(i==0){
                fill(255, 255, 0);
                circle(planetas.get(i).x, planetas.get(i).y, planetas.get(i).radius*2);

            }

            else if(planetas.get(i).x>0) {
                fill(181, 101, 29);
                circle(planetas.get(i).x, planetas.get(i).y, planetas.get(i).radius*2);

            }

        }


        //jogador 1 azul
        if(player.x>0 && player.y>0) {
            pushStyle();
            noFill();
            fill(0, 0, 255);
            circle(player.x, player.y, 50);

            float lineEndX = player.x + lineLength * cos(player.angle);
            float lineEndY = player.y + lineLength * sin(player.angle);
            stroke(0); // white
            line(player.x, player.y, lineEndX, lineEndY);
            popStyle();
        }

        //Jogador 2 vermelho
        if(enemy1.x>0) {
            pushStyle();
            noFill();
            fill(255, 0, 0);
            circle(enemy1.x, enemy1.y, 50);
            float lineEndX = enemy1.x + lineLength * cos(enemy1.angle);
            float lineEndY = enemy1.y + lineLength * sin(enemy1.angle);

            stroke(0); // white
            line(enemy1.x, enemy1.y, lineEndX, lineEndY);
            popStyle();
        }

        //Jogador 3 verde
        if(enemy2.x>0) {
            pushStyle();
            noFill();
            fill(0, 255, 0);
            circle(enemy2.x, enemy2.y, 50);
            float lineEndX = enemy2.x + lineLength * cos(enemy2.angle);
            float lineEndY = enemy2.y + lineLength * sin(enemy2.angle);

            stroke(0); // white
            line(enemy2.x, enemy2.y, lineEndX, lineEndY);
            popStyle();
        }

        //Jogador 4 rosa
        if(enemy3.x>0) {
            pushStyle();
            noFill();
            fill(255, 192, 203);
            circle(enemy3.x, enemy3.y, 50);
            float lineEndX = enemy3.x + lineLength * cos(enemy3.angle);
            float lineEndY = enemy3.y + lineLength * sin(enemy3.angle);

            stroke(0); // white
            line(enemy3.x, enemy3.y, lineEndX, lineEndY);
            popStyle();
        }

    }

    public void drawPostGameMenu(){
        background(menu_waiting);
        textSize(45);
        fill(255, 100, 0); // Set the fill color to a deep sunset-like orange
        text(info.answer,700,430);
        text("1 » Go Back",670,530);
    }


    @Override
    public void run() {
        String[] processingArgs = {"Menu"};
        Menu mySketch = new Menu(this.info,this.player,this.enemy1,this.enemy2,this.enemy3,this.planetas);
        PApplet.runSketch(processingArgs, mySketch);
    }






}
