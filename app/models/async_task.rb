class AsyncTask
  Tasks = HuiMain.async_tasks
  
  def self.start(&block)
    Tasks.remove({"create_at" => {"$lt" => 1.month.ago.to_time}})
    task_id = Tasks.insert({"progress" => 0, "create_at" => Time.now})

    if block then
      task = self.new(task_id)
      pid = Process.fork do
        block.call(task)
      end
      Process.detach(pid)
    end # else only create a document in db

    task_id
  end

  def initialize(task_id)
    @task_id = task_id
  end

  def set_total(total)
    Tasks.update({"_id" => @task_id}, {"$set" => {"total" => total}})
  end

  def set_progress(progress)
    Tasks.update({"_id" => @task_id}, {"$set" => {"progress" => progress}})
  end

  def finish_with(data)
    Tasks.update({"_id" => @task_id}, 
      {"$set" => {"finished" => true, "data" => data}})
  end

  def self.get_status(task_id)
    if task_id.is_a? String then
      task_id = BSON::ObjectId.from_string(task_id)
    end

    task_status = Tasks.find_one({"_id" => task_id}) || {}
    task_status.delete("_id")
    task_status
  end
end
