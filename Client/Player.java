public class Player {

    float x;
    float y;
    float angle;
    float radius;
    boolean[] keys=new boolean[3];


    public Player(){
        this.x=-100;
        this.y=-100;
        this.angle=-1;
        this.radius=25;
        this.keys[0]=false;
        this.keys[1]=false;
        this.keys[2]=false;
    }

}