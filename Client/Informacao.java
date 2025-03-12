import java.util.Map;
import java.util.Set;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;
enum Response {
    NOTHING,
    DONE,
    ERROR,
    SWITCH,
}
public class Informacao {
    public Lock lock = new ReentrantLock();
    public Condition waitPostman = lock.newCondition();
    public Condition waitScreen = lock.newCondition();
    public State opcao;

    public Response response = Response.NOTHING;

    public String username="";

    public String password="";

    public String Wstreak="";

    public String Level="";

    public String answer="";

    public int np=0;

    public String[] users ={"","","","","","","","","",""};
    public String[] levels ={"","","","","","","","","",""};
    public String[] wStreak ={"","","","","","","","","",""};
}